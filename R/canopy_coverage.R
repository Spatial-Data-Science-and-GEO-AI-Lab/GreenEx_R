
#' Calculate the percentage of a canopy within a given buffer distance or location
#'
#' @param address_location  A spatial object representing the location of interest, the location should be in projected coordinates.
#' @param vector_layer # A vector layer that represents a canopy, the layer should be in projected coordinates
#' @param buffer_distance A distance in meters to create a buffer or isochrone around the address location
#' @param net an optional sfnetwork object representing a road network
#' @param UID A character string representing a unique identifier for each point of interest
#' @param address_calculation A logical, indicating whether to calculate the address location (if not a point) as the centroid of the polygon containing it (default is 'TRUE')
#' @param speed A numeric value representing the speed in km/h to calculate the buffer distance (required if `time` is provided)
#' @param time A numeric value representing the travel time in minutes to calculate the buffer distance (required if `speed` is provided)
#'
#' @return The percentage of the canopy within a given buffer or isochrone around a set of locations is printed.
#' @export
#'
#' @examples
canopy_perc <- function(address_location, vector_layer, buffer_distance=NULL, net=NULL, UID=NULL, address_calculation = TRUE, speed=NULL, time=NULL){
  #Make sure main data set has projected CRS and save it
  if (sf::st_is_longlat(address_location)){
    stop("The CRS in your main data set has geographic coordinates, please transform it into your local projected CRS")

  }
  # Save the crs
  projected_crs <- sf::st_crs(address_location)

  if (address_calculation) {
    ### Check for any polygons, convert into centroids if there are any
    if ("POINT" %in% sf::st_geometry_type(address_location)) {
      # Do nothing
    } else if (missing(buffer_distance)) {
      stop("You do not have a point geometry and did not provide a buffer, please provide a point geometry or a buffer distance")
    }
    else {
      message('There are nonpoint geometries, they will be converted into centroids')
      address_location <- sf::st_centroid(address_location)
    }
    # Create a buffer or isochrone around the address location
    if (missing(buffer_distance)) {
      # Check for speed and time + Count buffer for bbox of initial set
      if(missing(speed)||missing(time)){
        stop("You didn't enter speed or time")
      } else if (!speed > 0) {
        stop("Speed must be a positive integer bigger than 0")
      } else if (!time > 0) {
        stop("Time must be a positive integer bigger than 0")
      } else{
        buffer_distance <- speed * 1000/ 60 * time
      }
      if (missing(net)) {
        ### Extracting OSM road structure to build isochrone polygon
        iso_area <- sf::st_buffer(sf::st_convex_hull(
          sf::st_union(sf::st_geometry(address_location))),
          buffer_distance)
        iso_area <- sf::st_transform(iso_area, crs = 4326)
        bbox <- sf::st_bbox(iso_area)
        q <- osmdata::opq(bbox) %>%
          osmdata::add_osm_feature(key = "highway") %>%
          osmdata::osmdata_sf()
        lines <- q$osm_lines
        polys <- q$osm_polygons


        #Remove Factors
        lines$osm_id <- as.numeric(as.character(lines$osm_id))
        polys$osm_id <- as.numeric(as.character(polys$osm_id))

        #remove the invalid polygons
        polys <- polys[!is.na(polys$highway),]
        polys <- polys[is.na(polys$area),]

        #Change Polygons to Lines
        polys <- sf::st_cast (polys, "LINESTRING")
        lines <- sf::st_cast (lines, "LINESTRING")

        # remove invalid geometry
        #lines <- lines[st_is_valid(lines) %in% TRUE,] # %in% TRUE handles NA that occure with empty geometries
        polys <- polys[sf::st_is_valid(polys) %in% TRUE,]
        #points <- points[st_is_valid(points) %in% TRUE,]

        #Bind together
        lines <- rbind(lines,polys)


        #Change to user projection
        lines <- sf::st_transform(lines, projected_crs)
        lines <- tidygraph::select(lines, "osm_id", "name")
        region_shp <- sf::st_transform(iso_area, projected_crs)

        #Download osm used a square bounding box, now trim to the exact boundary
        #note that lines that that cross the boundary are still included
        lines <- lines[region_shp,]

        # Round coordinates to 0 digits.
        sf::st_geometry(lines) <- sf::st_geometry(lines) %>%
          lapply(function(x) round(x, 0)) %>%
          sf::st_sfc(crs = sf::st_crs(lines))

        # Network
        net <- sfnetworks::as_sfnetwork(lines, directed = FALSE)
        net <- tidygraph::convert(net, sfnetworks::to_spatial_subdivision)



        #convert network to an sf object of edge
        net_sf <- net %>% tidygraph::activate("edges") %>%
          sf::st_as_sf()
        # Find which edges are touching each other
        touching_list <- sf::st_touches(net_sf)
        # create a graph from the touching list
        graph_list <- igraph::graph.adjlist(touching_list)
        # Identify the cpnnected components of the graph
        roads_group <- igraph::components(graph_list)
        # cont the number of edges in each component
        roads_table <- table(roads_group$membership)
        #order the components by size, largest to smallest
        roads_table_order <- roads_table[order(roads_table, decreasing = TRUE)]
        # get the name of the largest component
        biggest_group <- names(roads_table_order[1])

        # Subset the edges corresponding to the biggest connected component
        osm_connected_edges <- net_sf[roads_group$membership == biggest_group, ]
        # Filter nodes that are not connected to the biggest connected component
        net <- net %>%
          tidygraph::activate("nodes") %>%
          sf::st_filter(osm_connected_edges, .pred = sf::st_intersects)
      } else  {
        # If the CRS of the network data set is geographic, tranfrom it to the project CRS
        if (sf::st_crs(address_location) != sf::st_crs(net))
        {
          message("The CRS of your network data set is geographic, CRS of main data set will be used to transform")
          net <- sf::st_transform(net, projected_crs)
        }
      }
      net <- tidygraph::mutate(tidygraph::activate(net, "edges"),
                               weight = sfnetworks::edge_length())
      # Convert speed to m/s
      net <- net %>%
        tidygraph::activate("edges") %>%
        tidygraph::mutate(speed = units::set_units(speed[dplyr::cur_group_id()], "m/s")) %>%
        tidygraph::mutate(duration = weight / speed) %>%
        tidygraph::ungroup()

      ### Building isochrone polygon
      # activate the node layer of the network object
      net <- tidygraph::activate(net, "nodes")
      # Initialize an empty list to store isochrone polygons
      iso_list <- list()
      # loop through the input points
      for (i in 1:nrow(address_location)) {
        # assign the output of each iteration to the iso_list
        # filter the network object to include nodes that meet certain criteria
        # the code finds the set of nodes within.a certain travel time of each input point,
        # and stores it in a separate isochrone polygons
        iso_list[[i]] <- tidygraph::filter(net, tidygraph::node_distance_from(
          sf::st_nearest_feature(address_location[i,], net), weights = duration) <= time * 60)
      }

      # Building polygons
      iso_poly <- NULL
      for (i in 1:length(iso_list)) {
        iso_poly[i] <- iso_list[[i]] %>%
          # for each isochrone extract the geometry
          sf::st_geometry() %>%
          # combine them into a single geometry
          sf::st_combine() %>%
          # computes the smallest convex polygon that contains the geometry
          sf::st_convex_hull()
      }
      calculation_area <- sf::st_as_sf(sf::st_sfc(iso_poly)) %>% sf::st_set_crs(projected_crs)
    }else {
      message("Buffer distance is used for calculations")
      calculation_area <- sf::st_buffer(address_location, dist = buffer_distance)[2]
    }
  } else {
    calculation_area <- address_location
  }

  ### Make the calculations here
  canopy_pct <- list()

  # if (nrow(calculation_area) > 1){

    for (i in 1:nrow(calculation_area)) {
      # Clip tree canopy to polygon
      canopy_clip <- sf::st_intersection(vector_layer, calculation_area[i,])
      # Calculate area of clipped tree canopy
      canopy_area <- sf::st_area(canopy_clip)
      total_area <- sum(canopy_area)
      # Calculate area of polygon
      polygon_area <- sf::st_area(calculation_area[i,])
      # Calculate tree canopy percentage
      canopy_pct[i] <- total_area / polygon_area * 100


    }
    buffer <- calculation_area
    names(buffer) <- "buffer"
    df <- data.frame(UID = nrow(calculation_area), canopy_pct = cbind(unlist(canopy_pct)),
                     sf::st_geometry(address_location), buffer)
    df$UID <- seq.int(nrow(df))
    if (!missing(UID)){
      df$UID <- UID}

    df <- sf::st_as_sf(df)
  # else{
  #
  #   # Clip tree canopy to polygon
  #   canopy_clip <- sf::st_intersection(canopy, calculation_area)
  #   # Calculate area of clipped tree canopy
  #   canopy_area <- sf::st_area(canopy_clip)
  #   total_area <- sum(canopy_area)
  #   # Calculate area of polygon
  #   polygon_area <- sf::st_area(calculation_area)
  #   # Calculate tree canopy percentage
  #   canopy_pct <- total_area / polygon_area * 100
  #   buffer <- calculation_area
  #   names(buffer) <- "buffer"
  #   print(nrow(calculation_area))
  #   print(as.numeric(canopy_pct))
  #   df <- data.frame(UID = nrow(calculation_area), canopy_pct = as.numeric(canopy_pct), sf::st_geometry(address_location), buffer)
  #
  #   df$UID <- nrow(df)
  #   if (!missing(UID)){
  #     df$UID <- UID}
  # }
  #





  return(df)








}