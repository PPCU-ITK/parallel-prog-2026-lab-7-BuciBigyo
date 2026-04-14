#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

module load nvhpc
module load cuda
module load craype-accel-nvidia80

nvc++ -mp -Ofast cfd_euler.cpp -o cfd_euler_cpu
nvc++ -mp=gpu -gpu=cc80 -Ofast -DUSE_GPU cfd_euler.cpp -o cfd_euler_gpu -Minfo=accel,mp 2> gpu_compile_report.txt

OUT_DIR="cpu_gpu_outputs"
mkdir -p "$OUT_DIR"

RESULTS="$OUT_DIR/runtime_comparison.csv"
printf "mode,scale,Nx,Ny,nSteps,runtime_s,final_kinetic\n" > "$RESULTS"

append_result() {
  local file="$1"
  awk -F '[=,]' '{print $2 "," $4 "," $6 "," $8 "," $10 "," $12 "," $14}' "$file" >> "$RESULTS"
}

for scale in 1 4 8 16; do
  cpu_out="$OUT_DIR/cpu_scale_${scale}.txt"
  gpu_out="$OUT_DIR/gpu_scale_${scale}.txt"

  srun -p gpu --gres=gpu:1 --ntasks=1 --cpus-per-task=4 --time=00:20:00 --mem=40G \
    bash -lc "OMP_NUM_THREADS=4 ./cfd_euler_cpu $scale" > "$cpu_out"

  srun -p gpu --gres=gpu:1 --ntasks=1 --cpus-per-task=4 --time=00:20:00 --mem=40G \
    ./cfd_euler_gpu "$scale" > "$gpu_out"

  append_result "$cpu_out"
  append_result "$gpu_out"

  printf "Finished scale %s\n" "$scale"
done

printf "Wrote %s\n" "$RESULTS"
