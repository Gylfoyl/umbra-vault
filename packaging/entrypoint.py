"""PyInstaller entry point for the installed windowed executable."""

import sys

from app.main import main

sys.exit(main())
