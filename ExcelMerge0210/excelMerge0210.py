import pandas as pd
import glob
import os
import warnings

# Suppress openpyxl styling warnings
warnings.filterwarnings('ignore', category=UserWarning, module='openpyxl')

def merge_finance_tables(folder_path='.'):
    # Find all Excel files in the designated folder
    all_files = glob.glob(os.path.join(folder_path, '*.xlsx'))
    all_data = []

    for file in all_files:
        try:
            # 1. Read the raw file to locate the actual table header
            df_raw = pd.read_excel(file)
            
            # 2. Find the row index where the first column is 'תאריך רכישה' (Purchase Date)
            header_idx = df_raw[df_raw.iloc[:, 0] == 'תאריך רכישה'].index[0]
            
            # 3. Read the file again, setting that specific row as the column headers
            df = pd.read_excel(file, skiprows=header_idx + 1)
            
            # 4. Filter out footer rows (sums, legal text) by keeping only rows with a valid date format (DD.MM.YY)
            df = df[df['תאריך רכישה'].astype(str).str.contains(r'\d{2}\.\d{2}\.\d{2}', na=False, regex=True)]
            
            # 5. Optional: Add a column to track which file the transaction originally came from
            df['Source_File'] = os.path.basename(file)
            
            all_data.append(df)
            print(f"Successfully processed: {os.path.basename(file)}")
            
        except Exception as e:
            print(f"Skipping {os.path.basename(file)} due to error: {e}")

    # 6. Combine all the tables into one DataFrame
    if all_data:
        merged_df = pd.concat(all_data, ignore_index=True)
        
        # 7. Save the merged data to a new Excel file
        output_name = "Merged_Finance_Table.xlsx"
        merged_df.to_excel(output_name, index=False)
        print(f"\nSuccess! Merged {len(merged_df)} transactions from {len(all_data)} files into '{output_name}'.")
    else:
        print("\nNo valid tables were found to merge.")

# Run the function
merge_finance_tables('.')