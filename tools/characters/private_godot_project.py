"""Disposable project identity for checks that must never use normal user saves."""
from contextlib import contextmanager
from pathlib import Path
import shutil

@contextmanager
def private_project(root, directory):
    root=Path(root);directory=Path(directory);project=directory/'project';project.mkdir()
    userdata=Path.home()/'Library/Application Support'/directory.name
    try:
        for item in root.iterdir():
            if item.name not in ('.git','project.godot'):
                (project/item.name).symlink_to(item,target_is_directory=item.is_dir())
        config=(root/'project.godot').read_text().replace('[application]','[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'+directory.name+'"',1)
        (project/'project.godot').write_text(config)
        yield project
    finally:
        shutil.rmtree(userdata,ignore_errors=True)
