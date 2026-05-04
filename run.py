"""
Punto de entrada único del proyecto Proyección Turística.

Uso:
    python run.py          # Muestra ayuda
    python run.py extract  # Extrae datos (Python)
    python run.py transform # Transforma datos (R)
    python run.py assets   # Genera gráficos estáticos
    python run.py deploy        # Ambos deploys (Jekyll + Shiny)
    python run.py deploy-shiny  # Deploy dashboard a shinyapps.io
    python run.py deploy-jekyll # Copia archivos al repo Jekyll
    python run.py ver      # Lanza el dashboard Shiny local
    python run.py test     # Ejecuta tests + linting
    python run.py all      # Pipeline completo: extract -> transform -> assets -> deploy
"""

from __future__ import annotations

import glob
import os
import shutil
import subprocess
import sys

# Directorio raiz del proyecto (donde vive run.py)
_PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))


def _find_rscript() -> str:
    """Devuelve la ruta a Rscript, buscando en el PATH y ubicaciones comunes de Windows."""
    found = shutil.which("Rscript")
    if found:
        return found
    if sys.platform == "win32":
        for pattern in [
            os.path.join(os.environ.get("ProgramFiles", r"C:\Program Files"), "R", "R-*", "bin", "Rscript.exe"),
            os.path.join(os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)"), "R", "R-*", "bin", "Rscript.exe"),
        ]:
            matches = sorted(glob.glob(pattern), reverse=True)
            if matches:
                return matches[0]
    raise FileNotFoundError(
        "No se encontro Rscript. Instala R o agrega su directorio bin al PATH."
    )


_RSCRIPT = _find_rscript()

# --- Colores ANSI (se desactivan si la terminal no soporta) -----------


def _supports_color() -> bool:
    return hasattr(sys.stdout, "isatty") and sys.stdout.isatty()


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
        print(f"\n{_red('X')} {label} falló (exit code {result.returncode})")
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
        [_RSCRIPT, "transform/main.R"],
        "Transform - Transformando datos con R",
    )


def cmd_assets() -> bool:
    return _run(
        [_RSCRIPT, "export_charts.R"],
        "Assets - Generando gráficos estáticos",
    )


def cmd_deploy_jekyll() -> bool:
    return _run(
        [sys.executable, "scripts/deploy_jekyll.py"],
        "Deploy Jekyll - Copiando al repo Jekyll",
    )


def cmd_deploy_shiny() -> bool:
    return _run(
        [_RSCRIPT, "deploy.R"],
        "Deploy Shiny - Publicando dashboard a shinyapps.io",
    )


def cmd_deploy(args: list[str]) -> bool:
    if not args:
        ok = cmd_deploy_jekyll()
        ok2 = cmd_deploy_shiny()
        return ok and ok2

    target = args[0].lower()
    if target == "jekyll":
        return cmd_deploy_jekyll()
    if target == "shiny":
        return cmd_deploy_shiny()

    print(f"\n{_red('Error:')} Objetivo de deploy desconocido '{target}'")
    print(f"Uso: python run.py deploy [{_green('jekyll')} | {_green('shiny')}]")
    return False


def cmd_ver() -> bool:
    return _run(
        [_RSCRIPT, "-e", "shiny::runApp('dashboard')"],
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
        ("deploy", lambda: cmd_deploy([])),
    ]
    for name, fn in steps:
        if not fn():
            print(f"\n{_red('X')} Pipeline detenido en '{name}'.")
            return False
    print(f"\n{_green('OK')} Pipeline completo.")
    return True


def cmd_help() -> None:
    print(f"""
{_bold("Proyección Turística - Comandos disponibles")}

  python run.py {_green("extract")}           Extrae datos (Python)
  python run.py {_green("transform")}         Transforma datos (R)
  python run.py {_green("assets")}            Genera gráficos estáticos
  python run.py {_green("deploy")}             Ambos deploys (Jekyll + Shiny)
  python run.py {_green("deploy jekyll")}      Copia archivos al repo Jekyll
  python run.py {_green("deploy shiny")}       Publica dashboard a shinyapps.io
  python run.py {_green("ver")}               Lanza dashboard Shiny local
  python run.py {_green("test")}              Ejecuta tests (pytest) + linting (ruff)
  python run.py {_green("all")}               Pipeline completo: extract -> transform -> assets -> deploy

{_yellow("Ejemplo:")} python run.py deploy jekyll
""")


# --- Main -------------------------------------------------------------

COMMANDS = {
    "extract": lambda _: cmd_extract(),
    "transform": lambda _: cmd_transform(),
    "assets": lambda _: cmd_assets(),
    "deploy": lambda args: cmd_deploy(args),
    "deploy-shiny": lambda _: cmd_deploy_shiny(),
    "deploy-jekyll": lambda _: cmd_deploy_jekyll(),
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
