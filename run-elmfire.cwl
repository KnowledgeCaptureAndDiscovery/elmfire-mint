arguments:
- --
baseCommand: /elmfire/tutorials/06-landscape-optimization/01-run.sh
class: CommandLineTool
cwlVersion: v1.1
hints:
  DockerRequirement:
    dockerImageId: kcapd/elmfire:latest
inputs:
  fuel_file:
    inputBinding:
      prefix: --fuel_file
    type: File
  wind_file:
    inputBinding:
      prefix: --wind_file
    type: File
  simulation_tstop:
    inputBinding:
      prefix: --simulation_tstop
    type: int
outputs:
  time_of_arrival:
    outputBinding:
      glob: ./outputs/time_of_arrival_*.tif
    type: File
  flame_length:
    outputBinding:
      glob: ./outputs/flame_length_*.tif
    type: File
  fire_size_stats:
    outputBinding:
      glob: ./outputs/fire_size_stats.csv
    type: File
requirements:
  NetworkAccess:
    networkAccess: true
