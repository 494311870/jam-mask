class_name ResourceUtility

static func list_files(path: String, recursion: bool = false) -> Array[String]:
	var result: Array[String] = []
	var dir_access: DirAccess = DirAccess.open(path)

	dir_access.list_dir_begin()

	var next: String = dir_access.get_next()
	while next != "":
		var full_path: String = dir_access.get_current_dir() + "/" + next
		if dir_access.current_is_dir():
			if recursion:
				result.append_array(list_files(full_path, true))
		else:
			result.append(full_path)

		next = dir_access.get_next()

	dir_access.list_dir_end()

	result.assign(result.map(get_real_path))
	return result


static func get_real_path(full_path: String) -> String:
	return full_path.trim_suffix(".remap")


static func load_from_path(path: String, recursion: bool = false) -> Array:
	var files: Array[String] = list_files(path, recursion)
	return files.map(ResourceLoader.load)
