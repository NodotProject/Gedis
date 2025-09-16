# Contribution

This addon is implemented in GDScript and does not require native compilation. To work on or test the addon, follow these steps:

2.  **Develop & Test**:

- The addon code lives under `addons/Gedis`.
- Documentation is in the `docs` folder.
- Tests live in the `tests` directory.
- Run the project's test suite with `./run_tests.sh`.

3.  **Contribute**:

- addons/Gedis/gedis.gd should contain high level methods but little logic.
- Any logic should live in the other appropriate gdscript files
- Ensure new functionality has tests added and that the documentation is updated.