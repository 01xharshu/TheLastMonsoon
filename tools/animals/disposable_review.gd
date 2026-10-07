extends RefCounted
## The caller owns a temporary directory and removes it in finally cleanup.
## Without that explicit directory the review renders but writes no output.
static func _path(name:String)->String:
 var folder:=OS.get_environment("TLM_TEST_OUTPUT_DIR")
 if folder.is_empty():return ""
 var path:=folder.path_join(name)
 DirAccess.make_dir_recursive_absolute(path.get_base_dir())
 return path
static func save_png(pixels:Image,name:String)->void:
 var path:=_path(name)
 if not path.is_empty():pixels.save_png(path)
static func save_jpg(pixels:Image,name:String,quality:float=.91)->void:
 var path:=_path(name)
 if not path.is_empty():pixels.save_jpg(path,quality)
