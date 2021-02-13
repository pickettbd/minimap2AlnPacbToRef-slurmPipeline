# Long-read Mapping Pipeline
This is a pipeline for running [Minimap2](https://github.com/lh3/minimap2) on a SLURM-controlled Linux cluster.

## Directory Structure and Installation
These scripts assume a very specific directory structure and naming scheme.  
You can modify the scripts to avoid it, but using it should also be fairly straightforward.
First, create the directory structure:
```
mkdir some_project_dir
cd some_project_dir
mkdir -p data job_files/{success,failed}
git clone https://github.com/pickettbd/minimap2AlnPacbToRef-slurmPipeline scripts-alnPacb2Ref
```
The scripts *must* from the main project directory (some_project_dir) (*not* from the scripts-alnPacb2Ref dir).

## Data Requirements
This project is written to work with a "reference" genome (a non-official *de novo* assembly version is okay).
It also requires long-reads that will be aligned to the reference.
This project assumes these are PacBio reads.
It assumes the CLR reads are corrected with something like [Canu](https://github.com/marbl/canu), but they could be CCS/HiFi reads instead.

## Software Dependencies
These scripts assume a [GNU](https://www.gnu.org) [bash](https://www.gnu.org/software/bash) shell and cluster job submission controlled by [SLURM](https://slurm.schedmd.com).
The following tools are assumed to be installed on your machine with the executables available in your $PATH.  
The project assumes they are availble via system modules (e.g., Tcl or Lua), but removing the `module purge` and `module load _____` commands would remove the dependency on system modules.
- [Minimap2](https://github.com/lh3/minimap2) (v2.17-r941): A versatile pairwise aligner for genomic and spliced nucleotide sequences
- [samtools](https://www.htslib.org) (v1.11): Suites of programs for interacting with high-throughput sequencing data

## Notes
This pipeline does not support file names or paths that have whitespace in them.
Please run steps 00 and 01 to see instructions on how to set things up regarding where the assembly and reads are supposed to be located.
There will also be a description of how to specify certain options to the pipeline using `data/vars-longAln.list`.
The output alignments will be in the `data/alignments` directory.

## Licensing and Citation
Please see the `LICENSE` file for licensing information.
Please cite the author and this GitHub Repo if you rely on this repo for a project that ends up being published in any kind of peer-reviewed publication or presentation. Please include a link. 
