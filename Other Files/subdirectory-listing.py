import os

def list_files_in_subdirectories(directory):
    """
    Recursively list files in all subdirectories of the given directory.
    
    Args:
        directory (str): Path to the directory to explore
    """
    # Check if the directory exists
    if not os.path.isdir(directory):
        print(f"Error: {directory} is not a valid directory.")
        return
    
    # Walk through the directory
    for root, dirs, files in os.walk(directory):
        # Skip empty directories
        if not files:
            continue
        
        # Print the current subdirectory
        print(f"\nFiles in {root}:")
        
        # Print each file in the current subdirectory
        for file in files:
            print(os.path.join(root, file))

# Example usage
if __name__ == "__main__":
    # Replace with the path to the directory you want to explore
    target_directory = "C:\\Users\\carte\\Music\\Samples\\Iowa Samples"
    list_files_in_subdirectories(target_directory)