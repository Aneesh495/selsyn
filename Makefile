# Selsyn: IEEE C37.118 Synchrophasor Measurement Unit and Grid Frequency Stability Controller
# Makefile for building, testing, linting, and benchmarking

.PHONY: all test test-toit test-python lint bench clean check

all: test

test: test-toit test-python

test-toit:
	@echo "==> Running Toit unit and integration test suite..."
	@python3 tools/run_toit_tests.py

test-python:
	@echo "==> Running Python HIL and compliance test suite..."
	@python3 -m unittest discover -s tests -p "test_*.py"

lint:
	@echo "==> Verifying typography invariants (no em dashes or en dashes)..."
	@python3 tools/lint_no_em_dash.py
	@echo "==> Checking Toit syntax across core engine..."
	@toit analyze src/engine.toit

bench:
	@echo "==> Running Toit and Python performance benchmark suite..."
	@python3 benchmarks/benchmarks.py

check: lint test
	@echo "==> All verification checks PASSED successfully."

clean:
	@rm -rf build/ bin/ *.snapshot .packages/ recordings/ output/
	@find . -type d -name "__pycache__" -exec rm -rf {} +
