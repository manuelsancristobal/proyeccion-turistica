.PHONY: help install install-dev lint test coverage extract transform assets deploy-shiny deploy-jekyll deploy launch clean

help:
	@echo "Comandos disponibles:"
	@echo "  make install       Instalar dependencias Python"
	@echo "  make install-dev   Instalar proyecto + dependencias de desarrollo"
	@echo "  make lint          Ejecutar linting con ruff (Python)"
	@echo "  make test          Ejecutar tests con pytest"
	@echo "  make coverage      Ejecutar tests con reporte de cobertura"
	@echo "  make extract       Ejecutar capa Extract (Python)"
	@echo "  make transform     Ejecutar capa Transform (R)"
	@echo "  make assets        Generar gráficos estáticos para portafolio"
	@echo "  make deploy-shiny  Deploy dashboard a shinyapps.io"
	@echo "  make deploy-jekyll Deploy página al portafolio Jekyll"
	@echo "  make deploy        Ejecutar ambos deploys"
	@echo "  make launch        Lanzar dashboard localmente"
	@echo "  make clean         Eliminar archivos generados y caché"

install:
	pip install -e .

install-dev:
	pip install -e ".[dev]"
	pre-commit install

lint:
	ruff check extract/ scripts/
	ruff format --check extract/ scripts/

test:
	pytest tests/ -v

coverage:
	pytest tests/ -v --cov=extract --cov-report=html --cov-report=term-missing
	@echo "\nReporte de cobertura generado en htmlcov/index.html"

extract:
	python extract/main.py

transform:
	Rscript transform/main.R

assets:
	Rscript export_charts.R

deploy-shiny:
	Rscript deploy.R

deploy-jekyll:
	python scripts/deploy_jekyll.py

deploy: deploy-shiny deploy-jekyll

launch:
	Rscript -e "shiny::runApp('dashboard')"

clean:
	rm -rf build/ dist/ *.egg-info
	rm -rf .pytest_cache/ .coverage htmlcov/
	rm -rf .ruff_cache/
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true

.DEFAULT_GOAL := help
