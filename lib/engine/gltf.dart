import 'dart:convert';
import 'dart:typed_data';

import 'math3d.dart';
import 'mesh.dart';

/// One triangle primitive read from a glTF/GLB file, still in CPU memory.
/// [imageBytes] is the embedded base-color image (PNG or JPEG), if any.
class GltfPrimitiveData {
  final Mesh mesh;
  final Uint8List? imageBytes;
  final int tint;
  final bool doubleSided;

  const GltfPrimitiveData({
    required this.mesh,
    required this.tint,
    this.imageBytes,
    this.doubleSided = false,
  });
}

/// A parsed glTF 2.0 document. Images are still compressed bytes; decoding
/// them into [ui.Image]s happens in the model library so this stays free of
/// the Flutter binding (geometry tests can parse a GLB on their own).
class GltfDocument {
  final List<GltfPrimitiveData> primitives;

  const GltfDocument(this.primitives);
}

/// Reads a binary glTF (GLB) into meshes. Supports the subset these closet
/// models use, plus the node transforms a future export is likely to have:
/// one or more triangle primitives, POSITION / NORMAL / TEXCOORD_0, indexed
/// geometry, embedded images, and node TRS or matrix transforms.
///
/// glTF is Y-up, faces +Z, with counterclockwise front faces — the same
/// convention as [Mesh]. There is no skinning: a rigged file is loaded in
/// its bind pose.
///
/// TEXCOORD_0 is kept as stored. The closet GLBs were baked with V = 0 at
/// the top of the embedded image, which is already Flutter's sample origin.
/// Flipping V (the glTF bottom-left convention) lands most triangles in the
/// transparent gutter or on an unrelated island, so the figure draws as a
/// see-through patchwork.
GltfDocument parseGlb(Uint8List bytes) {
  if (bytes.length < 20) {
    throw const FormatException('GLB is too small');
  }
  final header = ByteData.sublistView(bytes);
  final magic = header.getUint32(0, Endian.little);
  if (magic != 0x46546C67) {
    throw const FormatException('Not a GLB file');
  }
  final version = header.getUint32(4, Endian.little);
  if (version != 2) {
    throw FormatException('Unsupported GLB version $version');
  }
  final length = header.getUint32(8, Endian.little);

  Uint8List? jsonChunk;
  Uint8List? binChunk;
  var offset = 12;
  while (offset + 8 <= length && offset + 8 <= bytes.length) {
    final chunkLen = header.getUint32(offset, Endian.little);
    final chunkType = header.getUint32(offset + 4, Endian.little);
    final start = offset + 8;
    final end = start + chunkLen;
    if (end > bytes.length) {
      throw const FormatException('GLB chunk overruns the file');
    }
    final chunk = Uint8List.sublistView(bytes, start, end);
    if (chunkType == 0x4E4F534A) jsonChunk = chunk;
    if (chunkType == 0x004E4942) binChunk = chunk;
    offset = end;
  }
  if (jsonChunk == null) {
    throw const FormatException('GLB has no JSON chunk');
  }
  final json = jsonDecode(utf8.decode(jsonChunk)) as Map<String, dynamic>;
  final bin = binChunk ?? Uint8List(0);
  return _readDocument(json, bin);
}

GltfDocument _readDocument(Map<String, dynamic> json, Uint8List bin) {
  final buffers = (json['buffers'] as List?) ?? const [];
  if (buffers.isNotEmpty && buffers.first['uri'] != null) {
    throw const FormatException('External glTF buffers are not supported');
  }
  final bufferViews = ((json['bufferViews'] as List?) ?? const [])
      .cast<Map<String, dynamic>>();
  final accessors = ((json['accessors'] as List?) ?? const [])
      .cast<Map<String, dynamic>>();
  final meshes = ((json['meshes'] as List?) ?? const [])
      .cast<Map<String, dynamic>>();
  final nodes = ((json['nodes'] as List?) ?? const [])
      .cast<Map<String, dynamic>>();
  final materials = ((json['materials'] as List?) ?? const [])
      .cast<Map<String, dynamic>>();
  final textures = ((json['textures'] as List?) ?? const [])
      .cast<Map<String, dynamic>>();
  final images = ((json['images'] as List?) ?? const [])
      .cast<Map<String, dynamic>>();

  if (accessors.any((a) => a['sparse'] != null)) {
    throw const FormatException('Sparse glTF accessors are not supported');
  }

  final reader = _AccessorReader(bin, bufferViews, accessors);
  final imageCache = <int, Uint8List?>{};

  Uint8List? imageBytes(int imageIndex) {
    return imageCache.putIfAbsent(imageIndex, () {
      final image = images[imageIndex];
      final view = image['bufferView'];
      if (view is int) return reader.bytesOfView(view);
      final uri = image['uri'];
      if (uri is String && uri.startsWith('data:')) {
        final comma = uri.indexOf(',');
        if (comma < 0) return null;
        return base64Decode(uri.substring(comma + 1));
      }
      if (uri != null) {
        throw FormatException('External glTF image is not supported: $uri');
      }
      return null;
    });
  }

  final out = <GltfPrimitiveData>[];
  final sceneIndex = (json['scene'] as int?) ?? 0;
  final scenes = (json['scenes'] as List?) ?? const [];
  final roots = scenes.isEmpty
      ? List<int>.generate(nodes.length, (i) => i)
      : ((scenes[sceneIndex]['nodes'] as List?) ?? const []).cast<int>();

  void visit(int nodeIndex, Affine parent) {
    final node = nodes[nodeIndex];
    final world = parent * _nodeLocal(node);
    final meshIndex = node['mesh'];
    if (meshIndex is int) {
      for (final prim
          in (meshes[meshIndex]['primitives'] as List)
              .cast<Map<String, dynamic>>()) {
        out.add(
          _primitive(prim, world, reader, materials, textures, imageBytes),
        );
      }
    }
    final children = (node['children'] as List?)?.cast<int>() ?? const <int>[];
    for (final child in children) {
      visit(child, world);
    }
  }

  if (roots.isEmpty && meshes.isNotEmpty) {
    for (final prim
        in (meshes.first['primitives'] as List).cast<Map<String, dynamic>>()) {
      out.add(
        _primitive(
          prim,
          Affine.identity,
          reader,
          materials,
          textures,
          imageBytes,
        ),
      );
    }
  } else {
    for (final root in roots) {
      visit(root, Affine.identity);
    }
  }
  if (out.isEmpty) {
    throw const FormatException('GLB does not contain a mesh');
  }
  return GltfDocument(out);
}

GltfPrimitiveData _primitive(
  Map<String, dynamic> prim,
  Affine world,
  _AccessorReader reader,
  List<Map<String, dynamic>> materials,
  List<Map<String, dynamic>> textures,
  Uint8List? Function(int imageIndex) imageBytes,
) {
  final mode = (prim['mode'] as int?) ?? 4;
  if (mode != 4) {
    throw FormatException(
      'Only triangle primitives are supported (mode $mode)',
    );
  }
  final attrs = (prim['attributes'] as Map).cast<String, dynamic>();
  final positionIndex = attrs['POSITION'];
  if (positionIndex is! int) {
    throw const FormatException('Mesh is missing POSITION');
  }
  var positions = reader.readVec3(positionIndex);
  // The cascade must not apply to both branches. `..setAll` binds looser
  // than `?:`, so writing it on the else branch also overwrites a real
  // index buffer with 0, 1, 2, … and the mesh draws as scrambled shards.
  final Uint32List indices;
  if (prim['indices'] is int) {
    indices = reader.readIndices(prim['indices'] as int);
  } else {
    final n = positions.length ~/ 3;
    indices = Uint32List(n);
    for (var i = 0; i < n; i++) {
      indices[i] = i;
    }
  }

  if (!_isIdentity(world)) {
    final moved = Float32List(positions.length);
    for (var i = 0; i < positions.length; i += 3) {
      final p = world.point(
        Vec3(positions[i], positions[i + 1], positions[i + 2]),
      );
      moved[i] = p.x;
      moved[i + 1] = p.y;
      moved[i + 2] = p.z;
    }
    positions = moved;
    if (_det(world) < 0) {
      for (var t = 0; t < indices.length; t += 3) {
        final tmp = indices[t + 1];
        indices[t + 1] = indices[t + 2];
        indices[t + 2] = tmp;
      }
    }
  }

  Float32List? uvs;
  final uvIndex = attrs['TEXCOORD_0'];
  if (uvIndex is int) {
    // Do not flip V. See the note on [parseGlb].
    uvs = reader.readVec2(uvIndex);
  }

  final normals = attrs['NORMAL'] is int && _isIdentity(world)
      ? reader.readVec3(attrs['NORMAL'] as int)
      : Mesh.computeNormals(positions, indices);

  var tint = 0xFFFFFFFF;
  Uint8List? image;
  var doubleSided = false;
  final materialIndex = prim['material'];
  if (materialIndex is int &&
      materialIndex >= 0 &&
      materialIndex < materials.length) {
    final material = materials[materialIndex];
    doubleSided = material['doubleSided'] == true;
    final pbr = material['pbrMetallicRoughness'];
    if (pbr is Map) {
      final factor = pbr['baseColorFactor'];
      if (factor is List && factor.length >= 3) {
        int ch(int i) => ((factor[i] as num) * 255).round().clamp(0, 255);
        final a = factor.length > 3
            ? ((factor[3] as num) * 255).round().clamp(0, 255)
            : 255;
        tint = (a << 24) | (ch(0) << 16) | (ch(1) << 8) | ch(2);
      }
      final tex = pbr['baseColorTexture'];
      if (tex is Map && uvs != null) {
        final textureIndex = tex['index'];
        if (textureIndex is int && textureIndex < textures.length) {
          final source = textures[textureIndex]['source'];
          if (source is int) image = imageBytes(source);
        }
      }
    }
  }

  return GltfPrimitiveData(
    mesh: Mesh(positions, normals, indices, null, uvs),
    imageBytes: image,
    tint: tint,
    doubleSided: doubleSided,
  );
}

Affine _nodeLocal(Map<String, dynamic> node) {
  final matrix = node['matrix'];
  if (matrix is List && matrix.length >= 16) {
    double m(int i) => (matrix[i] as num).toDouble();
    // glTF matrices are column-major.
    return Affine(
      m(0),
      m(4),
      m(8),
      m(1),
      m(5),
      m(9),
      m(2),
      m(6),
      m(10),
      m(12),
      m(13),
      m(14),
    );
  }
  final t = node['translation'];
  final r = node['rotation'];
  final s = node['scale'];
  final translation = t is List && t.length >= 3
      ? Vec3(
          (t[0] as num).toDouble(),
          (t[1] as num).toDouble(),
          (t[2] as num).toDouble(),
        )
      : Vec3.zero;
  final scale = s is List && s.length >= 3
      ? Vec3(
          (s[0] as num).toDouble(),
          (s[1] as num).toDouble(),
          (s[2] as num).toDouble(),
        )
      : Vec3.one;
  final rotation = r is List && r.length >= 4
      ? _quat(
          (r[0] as num).toDouble(),
          (r[1] as num).toDouble(),
          (r[2] as num).toDouble(),
          (r[3] as num).toDouble(),
        )
      : Affine.identity;
  return Affine.translation(translation) * rotation * Affine.scale(scale);
}

/// glTF quaternion (x, y, z, w) as a rotation matrix.
Affine _quat(double x, double y, double z, double w) {
  final x2 = x + x, y2 = y + y, z2 = z + z;
  final xx = x * x2, xy = x * y2, xz = x * z2;
  final yy = y * y2, yz = y * z2, zz = z * z2;
  final wx = w * x2, wy = w * y2, wz = w * z2;
  return Affine(
    1 - (yy + zz),
    xy - wz,
    xz + wy,
    xy + wz,
    1 - (xx + zz),
    yz - wx,
    xz - wy,
    yz + wx,
    1 - (xx + yy),
    0,
    0,
    0,
  );
}

bool _isIdentity(Affine m) =>
    m.a == 1 &&
    m.b == 0 &&
    m.c == 0 &&
    m.d == 0 &&
    m.e == 1 &&
    m.f == 0 &&
    m.g == 0 &&
    m.h == 0 &&
    m.i == 1 &&
    m.tx == 0 &&
    m.ty == 0 &&
    m.tz == 0;

double _det(Affine m) =>
    m.a * (m.e * m.i - m.f * m.h) -
    m.b * (m.d * m.i - m.f * m.g) +
    m.c * (m.d * m.h - m.e * m.g);

class _AccessorReader {
  final Uint8List bin;
  final List<Map<String, dynamic>> bufferViews;
  final List<Map<String, dynamic>> accessors;
  late final ByteData _data = ByteData.sublistView(bin);

  _AccessorReader(this.bin, this.bufferViews, this.accessors);

  Uint8List bytesOfView(int viewIndex) {
    final view = bufferViews[viewIndex];
    final start = (view['byteOffset'] as int?) ?? 0;
    final len = view['byteLength'] as int;
    return Uint8List.fromList(bin.sublist(start, start + len));
  }

  Float32List readVec3(int accessor) => _readFloats(accessor, 3);
  Float32List readVec2(int accessor) => _readFloats(accessor, 2);

  Uint32List readIndices(int accessor) {
    final a = accessors[accessor];
    final count = a['count'] as int;
    final type = a['componentType'] as int;
    final out = Uint32List(count);
    _each(a, 1, (element, base) {
      out[element] = switch (type) {
        5121 => _data.getUint8(base),
        5123 => _data.getUint16(base, Endian.little),
        5125 => _data.getUint32(base, Endian.little),
        _ => throw FormatException('Unsupported index component $type'),
      };
    });
    return out;
  }

  Float32List _readFloats(int accessor, int components) {
    final a = accessors[accessor];
    if (a['componentType'] != 5126 ||
        a['type'] != (components == 3 ? 'VEC3' : 'VEC2')) {
      throw FormatException('Expected float VEC$components accessor');
    }
    final count = a['count'] as int;
    final out = Float32List(count * components);
    _each(a, components, (element, base) {
      for (var c = 0; c < components; c++) {
        out[element * components + c] = _data.getFloat32(
          base + c * 4,
          Endian.little,
        );
      }
    });
    return out;
  }

  void _each(
    Map<String, dynamic> accessor,
    int components,
    void Function(int element, int byteOffset) emit,
  ) {
    final viewIndex = accessor['bufferView'];
    if (viewIndex is! int) {
      throw const FormatException('Accessor is missing a bufferView');
    }
    final view = bufferViews[viewIndex];
    final componentType = accessor['componentType'] as int;
    final componentBytes = switch (componentType) {
      5120 || 5121 => 1,
      5122 || 5123 => 2,
      5125 || 5126 => 4,
      _ => throw FormatException('Unsupported component type $componentType'),
    };
    final stride = (view['byteStride'] as int?) ?? components * componentBytes;
    final base =
        ((view['byteOffset'] as int?) ?? 0) +
        ((accessor['byteOffset'] as int?) ?? 0);
    final count = accessor['count'] as int;
    for (var i = 0; i < count; i++) {
      emit(i, base + i * stride);
    }
  }
}
