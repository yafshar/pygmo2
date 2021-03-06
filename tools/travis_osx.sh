#!/usr/bin/env bash

# Echo each command
set -x

# Exit on error.
set -e

wget https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh -O miniconda.sh;
export deps_dir=$HOME/local
export PATH="$HOME/miniconda/bin:$PATH"
bash miniconda.sh -b -p $HOME/miniconda
conda config --add channels conda-forge --force

if [[ "${PYGMO_BUILD_TYPE}" == *pagmo_head ]]; then
    conda_pkgs="cmake eigen nlopt ipopt boost-cpp tbb tbb-devel python=${PYTHON_VERSION} numpy cloudpickle dill numba pybind11 clang clangdev ipyparallel"
else
    conda_pkgs="cmake boost-cpp python=${PYTHON_VERSION} numpy cloudpickle dill numba pybind11 clang clangdev ipyparallel pagmo-devel"
fi
conda create -q -p $deps_dir -y
source activate $deps_dir
conda install $conda_pkgs -y

export CXX=clang++
export CC=clang

if [[ "${PYGMO_BUILD_TYPE}" == *pagmo_head ]]; then
    # Install pagmo.
    git clone https://github.com/esa/pagmo2.git
    cd pagmo2
    mkdir build
    cd build
    cmake ../ -DCMAKE_BUILD_TYPE=Debug -DBoost_NO_BOOST_CMAKE=ON -DPAGMO_WITH_EIGEN3=ON -DPAGMO_WITH_IPOPT=ON -DPAGMO_WITH_NLOPT=ON -DCMAKE_PREFIX_PATH=$deps_dir -DCMAKE_INSTALL_PREFIX=$deps_dir -DCMAKE_CXX_STANDARD=17
    make -j4 install VERBOSE=1
    cd ..
    cd ..
fi

# Create the build dir and cd into it.
mkdir build
cd build

# Build pygmo.
cmake ../ -DCMAKE_BUILD_TYPE=Debug -DBoost_NO_BOOST_CMAKE=ON -DCMAKE_PREFIX_PATH=$deps_dir -DCMAKE_INSTALL_PREFIX=$deps_dir -DCMAKE_CXX_STANDARD=17
make -j2 install VERBOSE=1
cd

ipcluster start --daemonize=True;
# Give some time for the cluster to start up.
sleep 20;

# Run the test suite.
python -c "import pygmo; pygmo.test.run_test_suite(1); pygmo.mp_island.shutdown_pool(); pygmo.mp_bfe.shutdown_pool()"

set +e
set +x
