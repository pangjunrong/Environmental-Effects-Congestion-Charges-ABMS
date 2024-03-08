# Instructions
## Creating the Road Network
1. You would download the RoadNetwork.kml file from the data source (which is also conveniently added in the /original folder)
2. You will need to run geo_convert.py to convert the .kml file into a .shp file (which also comes with several other files of different extension names and are necessary to run the .shp file properly). Remember to activate the virtual environment first before doing so.
3. You will need to use QGIS software to crop the shapefile in the /original folder using a cropbox created by yourself. (Refer to Online Tutorial)
4. You should save the CroppedRoadNetwork files in the root directory so it can be imported into NetLogo.

## Running the Model
1. The model currently runs on an invisible network of nodes which are all linked together, there is a line of code with "hidden" to keep these nodes out of view while allowing our agents to travel between them.