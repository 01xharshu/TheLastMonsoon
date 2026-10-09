extends SceneTree
## Lossless RSCC container recompression. Resource payload and paths are unchanged.
## Run with --headless --script <this script> -- --input=<file> --output=<file>.
## Uses Godot's own Zstandard codec; no Python packages or paid storage required.
const BLOCK_SIZE := 1024 * 1024

func _initialize() -> void:
	var input_path := ""
	var output_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--input="): input_path = argument.trim_prefix("--input=")
		if argument.begins_with("--output="): output_path = argument.trim_prefix("--output=")
	var result := recompress(input_path, output_path)
	if not result.is_empty(): print("PASS lossless RSCC recompression: ", result)
	quit(1 if result.is_empty() else 0)

static func recompress(input_path: String, output_path: String) -> Dictionary:
	if input_path.is_empty() or output_path.is_empty() or input_path == output_path:
		push_error("Provide separate --input and --output paths; validate before replacement.")
		return {}
	var source := FileAccess.open(input_path, FileAccess.READ)
	if source == null or source.get_buffer(4).get_string_from_ascii() != "RSCC":
		push_error("Input is not a Godot compressed binary resource.")
		return {}
	var mode := source.get_32()
	var old_block_size := source.get_32()
	var length := source.get_32()
	if mode != FileAccess.COMPRESSION_ZSTD or old_block_size == 0:
		push_error("Only Zstandard RSCC inputs are supported.")
		return {}
	var sizes: Array[int] = []
	for i in length / old_block_size + 1:
		sizes.append(source.get_32())
	var payload := PackedByteArray()
	for i in sizes.size():
		var expected := mini(old_block_size, length - i * old_block_size)
		var block := source.get_buffer(sizes[i]).decompress(maxi(expected, 1), mode)
		if block.size() != expected:
			push_error("Input decompression failed.")
			return {}
		payload.append_array(block)
	if source.get_buffer(4).get_string_from_ascii() != "RSCC" or source.get_position() != source.get_length():
		push_error("Invalid compressed resource footer.")
		return {}
	var before_bytes := source.get_length()
	source.close()
	var blocks: Array[PackedByteArray] = []
	for i in length / BLOCK_SIZE + 1:
		var raw := payload.slice(i * BLOCK_SIZE, mini((i + 1) * BLOCK_SIZE, length))
		var compressed := raw.compress(FileAccess.COMPRESSION_ZSTD)
		if compressed.decompress(maxi(raw.size(), 1), FileAccess.COMPRESSION_ZSTD) != raw:
			push_error("Recompression round-trip changed payload bytes.")
			return {}
		blocks.append(compressed)
	var target := FileAccess.open(output_path, FileAccess.WRITE)
	if target == null:
		push_error("Cannot create output.")
		return {}
	target.store_buffer("RSCC".to_ascii_buffer())
	target.store_32(FileAccess.COMPRESSION_ZSTD)
	target.store_32(BLOCK_SIZE)
	target.store_32(length)
	for block in blocks: target.store_32(block.size())
	for block in blocks: target.store_buffer(block)
	target.store_buffer("RSCC".to_ascii_buffer())
	target.flush()
	var write_error := target.get_error()
	target.close()
	var expected_bytes := 20 + blocks.size() * 4
	for block in blocks: expected_bytes += block.size()
	var written := FileAccess.open(output_path, FileAccess.READ)
	if write_error != OK or written == null or written.get_length() != expected_bytes:
		push_error("Incomplete compressed resource write; output rejected.")
		if written != null: written.close()
		DirAccess.remove_absolute(output_path)
		return {}
	written.close()
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(payload)
	return {"before_bytes": before_bytes, "after_bytes": expected_bytes, "payload_sha256": hash.finish().hex_encode()}
