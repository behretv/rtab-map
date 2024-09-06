#
# ROS2 with RTABMap
#
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

# Arguments
ARG ROS_DISTRO
ARG CATKIN_WS
ARG RTABMAP_TAG
ARG RTI_NC_LICENSE_ACCEPTED=yes
ARG MAKEFLAGS="-j 6"

# Global variables
ENV DEBIAN_FRONTEND=noninteractive \
  CATKIN_WS="${CATKIN_WS}" \
  LD_LIBRARY_PATH="/usr/local/lib${LD_LIBRARY_PATH:+:}${LD_LIBRARY_PATH}" \
  ROS_DISTRO="${ROS_DISTRO}" \
  RTABMAP_TAG="${RTABMAP_TAG}" \
  ROS_PACKAGE_PATH="/opt/ros/${ROS_DISTRO}/install" \
  RTAB_ROS_WS="${CATKIN_WS}/src/rtabmap_ros" \
  SKIP_KEYS="rtabmap find_object_2d Pangolin libopencv-dev libopencv-contrib-dev libopencv-imgproc-dev python-opencv python3-opencv"\
  WORKSPACE=/workspace

# Validate global variables are set
SHELL ["/bin/bash", "-c", "-o", "pipefail"]
RUN if [[ -z "${ROS_DISTRO}" ]] ; then exit 1 ; else echo "${ROS_DISTRO}" ; fi
RUN if [[ -z "${ROS_PACKAGE_PATH}" ]] ; then exit 1 ; else echo "${ROS_PACKAGE_PATH}" ; fi
RUN if [[ -z "${RTAB_ROS_WS}" ]] ; then exit 1 ; else mkdir -p -v "${RTAB_ROS_WS}" ; fi

# Clone dependencies
RUN git config --global advice.detachedHead false && \
  git clone --depth 1 --branch "${RTABMAP_TAG}" https://github.com/introlab/rtabmap.git /opt/rtabmap && \
  git clone --depth 1 --branch "${RTABMAP_TAG}" https://github.com/introlab/rtabmap_ros.git "${RTAB_ROS_WS}"

# Install RTAB MAP
WORKDIR /opt/rtabmap
RUN cmake -S . -B build -DWITH_PYTHON=OFF && \
  cmake --build build && \
  cmake --install build && \
  rm -rf build

# Install RTAB MAP ROS: --from-paths  might be "${RTAB_ROS_WS}/.."
WORKDIR "${CATKIN_WS}"
RUN source "${ROS_PACKAGE_PATH}/setup.bash" && \
  apt-get update && \
  rosdep install -y \
  --ignore-src \
  --from-paths "${RTAB_ROS_WS}"  \
  --rosdistro "${ROS_DISTRO}" \
  --skip-keys "${SKIP_KEYS}" && \
  rm -rf /var/lib/apt/lists/* && \
  apt-get clean

RUN source "${ROS_PACKAGE_PATH}/setup.bash" && \
  colcon build \
  --merge-install \
  --install-base "${ROS_PACKAGE_PATH}" \
  --base-paths "${RTAB_ROS_WS}" \
  --event-handlers console_direct+ \
  --ament-cmake-args " -Wno-dev" \
  && rm -rf \
  "${CATKIN_WS}/build" \
  "${CATKIN_WS}/log" \
  "${CATKIN_WS}/src" \
  "${CATKIN_WS}/*.rosinstall"

# Install python dependencies
COPY requirements.txt "${WORKSPACE}/config/requirements.txt"
RUN python3 -m pip install --no-cache-dir \
  pip~=24.0 \
  jetson-stats~=4.2.7 \
  && python3 -m pip install --no-cache-dir -r "${WORKSPACE}/config/requirements.txt"

# Install deviceQuery
WORKDIR /usr/local/cuda/samples/1_Utilities/deviceQuery
RUN make build && \
  cp deviceQuery /usr/local/bin/

# Setup entrypoint
WORKDIR "${WORKSPACE}"
CMD ["/bin/bash"]
COPY ros_entrypoint.sh /tmp/ros_entrypoint.sh
ENTRYPOINT ["/tmp/ros_entrypoint.sh"]
