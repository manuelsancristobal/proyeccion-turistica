"""
Punto de entrada único del proyecto Proyección Turística.

Uso:
    python run.py          # Muestra ayuda
    python run.py extract  # Extrae datos (Python)
    python run.py transform # Transforma datos (R)
    python run.py assets   # Genera gráficos estáticos
    python run.py deploy   # Copia archivos al repo Jekyll + Shiny
    python run.py ver      # Lanza el dashboard Shiny local
    python run.py test     # Ejecuta tests + linting
    python run.py all      # Pipeline completo: extract -> transform -> assets -> deploy
"""
from __future__ import annotations

import os
import subprocess
import sys

# Directorio raiz del proyecto (donde vive run.py)
_PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))

# --- Colores ANSI (se desactivan si la terminal no soporta) -----------

def _supports_color() -> bool:
    if not hasattr(sys.stdout, "isatty") or not sys.stdout.isatty():
        return False
    return True

_COLOR = _supports_color()

def _green(text: str) -> str:
    return f"\033[92m{text}\033[0m" if _COLOR else text

def _cyan(text: str) -> str:
    return f"\033[96m{text}\033[0m" if _COLOR else text

def _red(text: str) -> str:
    return f"\033[91m{text}\033[0m" if _COLOR else text

def _bold(text: str) -> str:
    return f"\033[1m{text}\033[0m" if _COLOR else text

def _yellow(text: str) -> str:
    return f"\033[93m{text}\033[0m" if _COLOR else text


# --- Helpers ----------------------------------------------------------

def _run(cmd: list[str], label: str) -> bool:
    """Ejecuta un comando y retorna True si fue exitoso."""
    print(f"\n{_cyan('>')} {_bold(label)}")
    print(f"  {' '.join(cmd)}\n")
    env = os.environ.copy()
    env["PYTHONPATH"] = _PROJECT_ROOT + os.pathsep + env.get("PYTHONPATH", "")
    result = subprocess.run(cmd, cwd=_PROJECT_ROOT, env=env)
    if result.returncode != 0:
        print(f"\n{_red('X')} {label} fallo (exit code {result.returncode})")
        return False
    print(f"\n{_green('OK')} {label}")
    return True


# --- Comandos ---------------------------------------------------------

def cmd_extract() -> bool:
    return _run(
        [sys.executable, "-m", "extract.main"],
        "Extract - Extrayendo datos",
    )


def cmd_transform() -> bool:
    return _run(
        ["Rscript", "transform/main.R"],
        "Transform - Transformando datos con R",
    )


def cmd_assets() -> bool:
    return _run(
        ["Rscript", "export_charts.R"],
        "Assets - Generando gráficos estáticos",
    )


def cmd_deploy() -> bool:
    ok = _run(
        [sys.executable, "scripts/deploy_jekyll.py"],
        "Deploy - Copiando al repo Jekyll",
    )
    ok2 = _run(
        ["Rscript", "deploy.R"],
        "Deploy - Publicando dashboard a shinyapps.io",
    )
    return ok and ok2


def cmd_ver() -> bool:
    return _run(
        ["Rscript", "-e", "shiny::runApp('dashboard')"],
        "Ver - Ejecutando dashboard Shiny localmente",
    )


def cmd_test() -> bool:
    ok = _run(
        [sys.executable, "-m", "pytest", "tests/", "-v"],
        "Tests - pytest",
    )
    ok2 = _run(
        [sys.executable, "-m", "ruff", "check", "extract/", "scripts/", "tests/"],
        "Linting - ruff",
    )
    return ok and ok2


def cmd_all(args: list[str]) -> bool:
    steps = [
        ("extract", cmd_extract),
        ("transform", cmd_transform),
        ("assets", cmd_assets),
        ("deploy", cmd_deploy),
    ]
    for name, fn in steps:
        if not fn():
            print(f"\n{_red('X')} Pipeline detenido en '{name}'.")
            return False
    print(f"\n{_green('OK')} Pipeline completo.")
    return True


def cmd_help() -> None:
    print(f"""
{_bold('Proyección Turística - Comandos disponibles')}

  python run.py {_green('extract')}      Extrae datos (Python)
  python run.py {_green('transform')}    Transforma datos (R)
  python run.py {_green('assets')}       Genera gráficos estáticos
  python run.py {_green('deploy')}       Copia al Jekyll + publica a Shiny
  python run.py {_green('ver')}          Lanza dashboard Shiny local
  python run.py {_green('test')}         Ejecuta tests (pytest) + linting (ruff)
  python run.py {_green('all')}          Pipeline completo: extract -> transform -> assets -> deploy

{_yellow('Ejemplo:')} python run.py all
""")


# --- Main -------------------------------------------------------------

COMMANDS = {
    "extract": lambda _: cmd_extract(),
    "transform": lambda _: cmd_transform(),
    "assets": lambda _: cmd_assets(),
    "deploy": lambda _: cmd_deploy(),
    "ver": lambda _: cmd_ver(),
    "test": lambda _: cmd_test(),
    "all": lambda args: cmd_all(args),
}


def main() -> None:
    args = sys.argv[1:]

    if not args or args[0] in ("-h", "--help", "help"):
        cmd_help()
        sys.exit(0)

    command = args[0]
    if command not in COMMANDS:
        print(f"{_red('Error:')} Comando desconocido '{command}'")
        cmd_help()
        sys.exit(1)

    extra_args = args[1:]
    ok = COMMANDS[command](extra_args)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
