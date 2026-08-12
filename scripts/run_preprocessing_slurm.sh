#!/bin/bash
##
# Submit IceNet preprocessing jobs to SLURM
#
# Usage:
#   run_preprocessing_slurm.sh [prep_script_name] [hemisphere] [download] [dry]
#
# Arguments:
#   prep_script_name: Name of preprocessing script (default: prep_osisaf_training_data.sh)
#   hemisphere:       north|south (default: both hemispheres via array job)
#   download:         0|1 (default: 0, whether to download data)
#   dry:              0|1 (default: 0, dry run mode)
#
# Examples:
#   ./scripts/run_preprocessing_slurm.sh prep_osisaf_training_data.sh        # Both hemispheres, no download, not dry
#   ./scripts/run_preprocessing_slurm.sh prep_osisaf_training_data.sh north  # North only
#   ./scripts/run_preprocessing_slurm.sh prep_osisaf_training_data.sh north 1 0  # North, with download
#   ./scripts/run_preprocessing_slurm.sh prep_osisaf_training_data.sh south 0 1  # South, dry run
#   ./scripts/run_preprocessing_slurm.sh prep_osisaf_training_data_oras5.sh "" 1  # ORAS5, both hemispheres, download
#
# This script creates an inline SLURM script and submits it to run preprocessing
##

set -e

# Get arguments
PREP_SCRIPT=${1:-"prep_osisaf_training_data.sh"}
HEMISPHERE=${2:-""}
DOWNLOAD=${3:-0}
DRY=${4:-0}

# Create logs directory
mkdir -p logs

# Determine SLURM array setting
if [ -z "$HEMISPHERE" ]; then
    ARRAY_ARG="--array=0-1"
    HEMI_DESC="both hemispheres"
else
    ARRAY_ARG=""
    HEMI_DESC="hemisphere: $HEMISPHERE"
fi

echo "=================================================="
echo "Submitting IceNet preprocessing job to SLURM"
echo "=================================================="
echo "Script:     ${PREP_SCRIPT}"
echo "Hemisphere: ${HEMI_DESC}"
echo "Download:   ${DOWNLOAD}"
echo "Dry mode:   ${DRY}"
echo "Working dir: $(pwd)"
echo "=================================================="
echo ""

# Create inline SLURM script and submit
sbatch ${ARRAY_ARG} <<EOF
#!/bin/bash
#SBATCH --job-name=icenet_preproc
#SBATCH --output=logs/preproc_%j_%a.out
#SBATCH --error=logs/preproc_%j_%a.err
#SBATCH --partition=rocky
#SBATCH --account=rocky
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=24:00:00

set -e

# Create logs directory if it doesn't exist
mkdir -p logs

# Get hemisphere from command line or array index
if [ -n "${HEMISPHERE}" ]; then
    # Hemisphere specified on command line
    HEMI=${HEMISPHERE}
    echo "Running for hemisphere: \${HEMI} (from command line)"
else
    # Use array index (0=north, 1=south)
    if [ \${SLURM_ARRAY_TASK_ID} -eq 0 ]; then
        HEMI="north"
    else
        HEMI="south"
    fi
    echo "Running for hemisphere: \${HEMI} (from array index \${SLURM_ARRAY_TASK_ID})"
fi

echo "=================================================="
echo "IceNet Preprocessing - SLURM Job"
echo "=================================================="
echo "Job ID:        \${SLURM_JOB_ID}"
echo "Array Task ID: \${SLURM_ARRAY_TASK_ID:-N/A}"
echo "Node:          \${SLURMD_NODENAME}"
echo "Script:        ${PREP_SCRIPT}"
echo "Hemisphere:    \${HEMI}"
echo "Start time:    \$(date)"
echo "=================================================="
echo ""

# Activate conda environment
echo "Activating conda environment: icenet4"
source /data/hpcdata/users/benevans/miniforge3/etc/profile.d/conda.sh
conda activate icenet4

# Verify environment
echo "Python:  \$(which python)"
echo "Conda:   \$CONDA_DEFAULT_ENV"
echo ""

# Source environment variables
echo "Sourcing ENVS configuration..."
source ENVS
echo ""

# Show key environment variables
echo "Configuration:"
echo "  LAG:              \$LAG"
echo "  VAR_LAG_OVERRIDE: \$VAR_LAG_OVERRIDE"
echo "  BATCH_SIZE:       \$BATCH_SIZE"
echo "  PREFIX:           \$PREFIX"
echo "  DOWNLOAD:         ${DOWNLOAD}"
echo "  DRY:              ${DRY}"
echo ""

# Add scripts to PATH
export PATH="\$(pwd)/scripts:\$PATH"

# Run the preprocessing script
echo "=================================================="
echo "Running: ${PREP_SCRIPT} \${HEMI} ${DOWNLOAD} ${DRY}"
echo "=================================================="
echo ""

cd "\$(pwd)"
bash scripts/${PREP_SCRIPT} \${HEMI} ${DOWNLOAD} ${DRY}

EXIT_CODE=\$?

echo ""
echo "=================================================="
echo "Job completed"
echo "Exit code:  \${EXIT_CODE}"
echo "End time:   \$(date)"
echo "=================================================="

exit \${EXIT_CODE}
EOF

echo ""
echo "Job submitted. Check status with: squeue -u $USER"
echo "View logs in: logs/preproc_*.{out,err}"
