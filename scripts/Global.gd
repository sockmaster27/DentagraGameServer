extends Node


const token_length := 64


func bytes_to_int(bytes: PoolByteArray) -> int:
	var sp_buffer := StreamPeerBuffer.new()
	sp_buffer.set_data_array(bytes)
	return sp_buffer.get_u64()
