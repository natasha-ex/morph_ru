import time
import pymorphy3

words = [
    "стали", "московским", "сирота", "договора", "январе",
    "красивый", "бежать", "дом", "работа", "программирование",
    "государственный", "предприниматель", "ответственность",
    "законодательство", "международный",
]

m = pymorphy3.MorphAnalyzer()

# Warm up
for w in words:
    m.parse(w)

N = 1000

start = time.perf_counter()
for _ in range(N):
    for w in words:
        m.parse(w)
elapsed = time.perf_counter() - start
print(f"parse: {elapsed/N*1000:.3f} ms per iteration ({len(words)} words)")

start = time.perf_counter()
for _ in range(N):
    for w in words:
        m.tag(w)
elapsed = time.perf_counter() - start
print(f"tag:   {elapsed/N*1000:.3f} ms per iteration ({len(words)} words)")
