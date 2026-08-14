import yaml
import sys

REMOVE_NAMES = {"catalog-mysql", "orders-postgresql", "carts-dynamodb"}

input_path = sys.argv[1]
output_path = sys.argv[2]

with open(input_path, "r") as f:
    docs = list(yaml.safe_load_all(f))

kept = []
removed = []

for doc in docs:
    if doc is None:
        continue
    name = doc.get("metadata", {}).get("name", "")
    kind = doc.get("kind", "")
    if name in REMOVE_NAMES:
        removed.append(f"{kind}/{name}")
        continue
    kept.append(doc)

with open(output_path, "w") as f:
    yaml.dump_all(kept, f, default_flow_style=False, sort_keys=False)

print(f"Removed {len(removed)} resources:")
for r in removed:
    print(f"  - {r}")
print(f"Kept {len(kept)} resources total.")
print(f"Written to {output_path}")
