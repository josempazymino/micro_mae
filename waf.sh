#!/bin/bash

#SBATCH --job-name=waf_main
#SBATCH --ntasks=8
#SBATCH --mem=65536
#SBATCH --time=6:00:00
#SBATCH --tmp=20G
#SBATCH --partition=normal
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jose.pazymino@ucu.edu.uy

#virtualenv-3 ENV

#source ENV/bin/activate
source /clusteruy/home/jose.pazymino/miniconda3/bin/activate
#PREFIX=/clusteruy/home/jose.pazymino/miniconda3
#environment location: /clusteruy/home/jose.pazymino/miniconda3

conda install pandas
conda install numpy
conda install functools
conda install pickle
conda install statsmodels
conda install patsy
conda install DateTime
conda install seaborn
conda install matplotlib
conda install unidecode
conda install -c anaconda unidecode
conda install -c anaconda scikit-learn


cd ~/price_dispersion

python waf.py configure

python waf.py build -j1 -v
