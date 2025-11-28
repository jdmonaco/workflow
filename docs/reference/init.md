# wfw init

Initialize a WireFlow project with `.workflow/` structure.

## Usage

```
wfw init [<directory>]
```

## Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `<directory>` | Directory to initialize | Current directory |

## Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Quick help |

## What Gets Created

```
<directory>/
└── .workflow/
    ├── config              # Project-level configuration
    ├── project.txt         # Project description (optional)
    ├── cache/              # File conversion cache
    ├── output/             # Hardlinks to workflow outputs
    └── run/                # Workflow directories
```

## Behavior

- Creates `.workflow/` directory structure
- Use `wfw edit` afterward to open `project.txt` and `config` in your editor
- If already initialized, shows error message

## Examples

```bash
# Initialize current directory
wfw init .

# Initialize new directory
wfw init my-project

# Initialize specific path
wfw init ~/research/new-study
```

## See Also

- [Projects Guide](../user-guide/projects.md) - Project structure and concepts
- [`wfw new`](new.md) - Create workflows after initialization
