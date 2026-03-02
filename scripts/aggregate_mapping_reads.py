import os
import json
import pandas as pd

# Change this to the root directory containing the reference directories
root_dir = "results/02_kallisto/"  # Update this path as needed

# Dictionary to store data: {sample: {reference: p_pseudoaligned}}
data = {}

# Iterate through first-level directories (references)
for reference in sorted(os.listdir(root_dir)):
    # skip non-directories and the figures folder
    ref_path = os.path.join(root_dir, reference)
    if not os.path.isdir(ref_path):
        continue

    # Iterate through second-level directories (samples)
    for sample in sorted(os.listdir(ref_path)):
        sample_path = os.path.join(ref_path, sample)
        run_info_path = os.path.join(sample_path, "run_info.json")

        if os.path.isfile(run_info_path):
            with open(run_info_path) as f:
                run_info = json.load(f)
                p_val = run_info.get("p_pseudoaligned", None)

            if sample not in data:
                data[sample] = {}
            data[sample][reference] = p_val

# Convert to DataFrame
df = pd.DataFrame.from_dict(data, orient="index")
df.index.name = "Sample"
df.columns.name = "Reference"

# Save table to CSV
output_csv = os.path.join(root_dir, "p_pseudoaligned_table.csv")
df.to_csv(output_csv)

print(f"Table saved to {output_csv}")
print(df)
