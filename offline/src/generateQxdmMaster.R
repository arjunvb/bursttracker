library(doParallel)
library(foreach)

generateMasterFilesFromQxdmTtis <- function( pathToQxdmOut, pathToQxdmMaster, qxdmTtisFileName, kpisInMaster, minInterBurstTime, minInterChunkTime, userIdKpi, numPrbsPerTti ) {
	
	#########################################
	# LOAD QXDM.TTIS
	cat( "************** \n" )
	cat( paste( "Loading", qxdmTtisFileName,  "..." ), "\n" )
	qxdmTtis <- read.csv( paste0( pathToQxdmOut, qxdmTtisFileName ), row.names = NULL )
	cat( paste( "...loaded", qxdmTtisFileName, "with", nrow( qxdmTtis ), "rows,", ncol( qxdmTtis ), "columns, and", length( unique( qxdmTtis[ , userIdKpi ] ) ), "unique", userIdKpi ), "\n" )

	#########################################
	# GENERATE MAST.TTIS
	cat( "************** \n" )
	cat( "Generating MAST.TTIS... \n" )
	mastTtis <- generateMasterTtisFromQxdmTtis( qxdmTtis, minInterBurstTime, minInterChunkTime, userIdKpi, numPrbsPerTti )
	cat( paste( "...generated MAST.TTIS with", nrow( mastTtis ), "rows and", ncol( mastTtis ), "columns" ), "\n" )	
	
	#########################################
	# SAVE MAST.TTIS
	cat( "Writing MAST.TTIS to file... \n" )
	write.table( mastTtis, file = paste0( pathToQxdmMaster, gsub( "QXDM.TTIS", "MAST.TTIS", qxdmTtisFileName ) ), row.names = F, quote = F, sep = "," )
	cat( "...written! \n" )

	#########################################
	# FIND UNIXTIME OFFSET
	cat( "************** \n" )
	cat( "Finding unix time offset... \n" )
	startIndexPerUser <- unlist( lapply( lapply( unique( mastTtis$IMEIX ), function( x ) { which( mastTtis$UNIXTime %in% min( mastTtis$UNIXTime[ mastTtis$IMEIX %in% x ], na.rm = T ) ) } ), function( x ) { min( x ) } ) )
	unixTimeOffset <- round( mean( mastTtis$UNIXTime[ startIndexPerUser ] / 1000 - mastTtis$TIME[ startIndexPerUser ], na.rm = T ), digits = 3 ) # round to 3 decimal places (granularity of a millisecond)
	cat( paste( "...found unix time offset to be", unixTimeOffset, "corresponding to datetime", as.POSIXct( unixTimeOffset, origin = "1970-01-01", tz = "UTC" ), "UTC" ), "\n" )

	#########################################
	# GENERATE MAST.BURR
	cat( "************** \n" )
	cat( "Generating MAST.BURR... \n" )
	mastBurr <- generateMasterBurrFromQxdmTtis( mastTtis, minInterBurstTime, numPrbsPerTti, kpisInMaster, unixTimeOffset )
	cat( paste( "...generated MAST.BURR with", nrow( mastBurr ), "rows and", ncol( mastBurr ), "columns" ), "\n" )	
	
	#########################################
	# SAVE MAST.BURR
	cat( "Writing MAST.BURR to file... \n" )
	write.table( mastBurr, file = paste0( pathToQxdmMaster, gsub( "QXDM.TTIS", "MAST.BURR", qxdmTtisFileName ) ), row.names = F, quote = F, sep = "," )
	cat( "...written! \n" )

	#########################################
	# GENERATE MAST.CHNK
	cat( "************** \n" )
	cat( "Generating MAST.CHNK... \n" )
	mastChnk <- generateMasterChnkFromQxdmTtis( mastTtis, minInterChunkTime, numPrbsPerTti, kpisInMaster, unixTimeOffset )
	cat( paste( "...generated MAST.CHNK with", nrow( mastChnk ), "rows and", ncol( mastChnk ), "columns" ), "\n" )	
	
	#########################################
	# SAVE MAST.CHNK
	cat( "Writing MAST.CHNK to file... \n" )
	write.table( mastChnk, file = paste0( pathToQxdmMaster, gsub( "QXDM.TTIS", "MAST.CHNK", qxdmTtisFileName ) ), row.names = F, quote = F, sep = "," )
	cat( "...written! \n" )

	#########################################
	# GENERATE MAST.SESS
	cat( "************** \n" )
	cat( "Generating MAST.SESS... \n" )
	mastSess <- generateMasterSessFromQxdmTtis( mastBurr, mastChnk, numPrbsPerTti, kpisInMaster )
	cat( paste( "...generated MAST.SESS with", nrow( mastSess ), "rows and", ncol( mastSess ), "columns" ), "\n" )	
	
	#########################################
	# SAVE MAST.SESS
	cat( "Writing MAST.SESS to file... \n" )
	write.table( mastSess, file = paste0( pathToQxdmMaster, gsub( "QXDM.TTIS", "MAST.SESS", qxdmTtisFileName ) ), row.names = F, quote = F, sep = "," )
	cat( "...written! \n" )

}

################################################################
# MAST.TTIS

generateMasterTtisFromQxdmTtis <- function( qxdmTtis, minInterBurstTime, minInterChunkTime, userIdKpi, numPrbsPerTti ) {
	
	# initialize mastTtis
	mastTtis <- qxdmTtis
	
	# user id
	mastTtis[ , "USER_ID" ] <- mastTtis[ , userIdKpi ]
	
	# timestamp per tti (relative to start)
	mastTtis[ , "TIME" ] <- ( mastTtis$FRAMEID * 10 + mastTtis$SUBFRAME ) / 1000 # seconds
	mastTtis <- mastTtis[ order( mastTtis$TIME ), ] # make sure the rows are ordered by time

	# volume per tti
	mastTtis[ , "VOL_DL" ] <- ( mastTtis$TBS1 + pmax( 0, mastTtis$TBS2 ) ) / 8 # bytes

	# rank
	mastTtis[ , "RANK_DL" ] <- ( mastTtis$TBS1 * 1 + pmax( 0, mastTtis$TBS2 ) * 2 ) / ( mastTtis$TBS1 + pmax( 0, mastTtis$TBS2 ) )

	# modulation
	mastTtis[ , "MOD_DL" ] <- ( mastTtis$MOD1 * mastTtis$TBS1 + ifelse( mastTtis$TBS2 < 0, 0, mastTtis$MOD2 * mastTtis$TBS2 ) ) / ( mastTtis$TBS1 + ifelse( mastTtis$TBS2 < 0, 0, mastTtis$TBS2 ) )

	# list of users
	userList <- unique( mastTtis[, userIdKpi ] )
	
	# burst id and session id
	for( user in userList ) {

		cat( paste( "Started processing user", user, ":", match( user, userList ), "of", length( userList ), ": at", Sys.time() ), "\n" )
	
		# find row indices of the current user
		userIndices <- which( mastTtis[ , userIdKpi ] %in% user )
	
		# subselect records for the current user
		mastTtisUser <- mastTtis[ userIndices, ]

		# duration of preceeding empty slots
		mastTtis[ userIndices, "PREVEMP_DUR"] <- 1000 * ( mastTtisUser$TIME - c( head( mastTtisUser$TIME, 1 ), head( mastTtisUser$TIME, -1 ) ) ) - 1 # milliseconds (TTIs)
		mastTtis[ userIndices, "PREVEMP_DUR" ] <- round( mastTtis$PREVEMP[ userIndices ], digits = 0 )
        mastTtis[ userIndices, "NEXTEMP_DUR" ] <- 1000 * ( c( tail( mastTtisUser$TIME, -1), tail(mastTtisUser$TIME, 1 ) ) - mastTtisUser$TIME ) - 1
        mastTtis[ userIndices, "NEXTEMP_DUR" ] <- round( mastTtis$NEXTEMP[ userIndices ], digits = 0 )

        burstEndCandidates <- which( mastTtis$NALLOC[ userIndices ] < 20 & mastTtis$NEXTEMP[ userIndices ] > 0 )
        #burstEnds <- burstEnds[ which(burstEnds > which( mastTtis$NALLOC[ userIndices ] == numPrbsPerTti )[1]) ]
        
        burstStarts <- c()
        burstEnds <- c()
        fullTtis <- which( mastTtis$NALLOC[ userIndices ] > 45 )
        for (idx in 1:length(burstEndCandidates)) {
          burstStartCandidates <- ifelse(idx == 1, which(fullTtis < burstEndCandidates[idx]), which(fullTtis > burstEndCandidates[idx-1] & fullTtis < burstEndCandidates[idx]))
          if ( !is.na(burstStartCandidates) ) {
            burstStarts <- c(burstStarts, min( fullTtis[burstStartCandidates] ))
            burstEnds <- c(burstEnds, burstEndCandidates[idx])
          }
        }
       
        cat( paste0( "burstStarts = ", length(burstStarts), "\n") )
        cat( paste0( "burstEnds = ", length(burstEnds), "\n") )

		# burst id
		#burstStarts <- which( mastTtis$PREVEMP[ userIndices ] >= minInterBurstTime ) 

        for (idx in 1:length(burstStarts)) {
          mastTtis[ burstStarts[idx]:burstEnds[idx], "BURST_ID" ] <- rep(idx, burstEnds[idx]-burstStarts[idx]+1)
        }
        #mastTtis[ userIndices, "BURST_ID" ] <- unlist( lapply( seq( 1, nrow( mastTtisUser ) ), function( x ) { sum( x >= burstStarts ) + 1 } ) )

		# chunk id
		chunkStarts <- which( mastTtis$PREVEMP[ userIndices ] >= minInterChunkTime ) 
		mastTtis[ userIndices, "CHUNK_ID" ] <- unlist( lapply( seq( 1, nrow( mastTtisUser ) ), function( x ) { sum( x >= chunkStarts ) + 1 } ) )
		
        # session id
		sessStarts <- which( mastTtis$PREVEMP[ userIndices ] >= 5000 ) # separation of 10 seconds (10000 milliseconds) implies different sessions
		mastTtis[ userIndices, "SESSION_ID" ] <- unlist( lapply( seq( 1, nrow( mastTtisUser ) ), function( x ) { sum( x >= sessStarts ) + 1 } ) )

        mastTtis[ userIndices, "PRBUTIL" ] <- mastTtis$NALLOC[ userIndices ] / numPrbsPerTti

	}
	
	# return mastTtis
	return( mastTtis )
	
}

################################################################
# MAST.BURR

generateMasterBurrFromQxdmTtis <- function( mastTtis, minInterBurstTime, numPrbsPerTti, kpisInMaster, unixTimeOffset ) {
		
	# list of users
	userList <- unique( mastTtis[ , userIdKpi ] )
	
	# initialize list to contain mastBurrUsers
	mastBurrUsers <- NULL
	
	for( user in userList ) {
		
		cat( paste( "Started processing user", user, ":", match( user, userList ), "of", length( userList ), ": at", Sys.time() ), "\n" )
		
		# pick mastTtis for the current user
		mastTtisUser <- mastTtis[ which( mastTtis[ , userIdKpi ] %in% user ), ]
		
		# initialize mastBurrUser
		mastBurrUser <- data.frame( matrix( NA, nrow = max( mastTtisUser$BURST_ID, na.rm = T ), ncol = length( kpisInMaster ) ) )
		colnames( mastBurrUser ) <- kpisInMaster

		# compute kpis
		for( burstId in seq( 1, nrow( mastBurrUser ) ) ) {
	
			if( burstId %% 1000 == 1 ) {
				cat( paste( "...reached burst", burstId, "of", nrow( mastBurrUser ), "at", Sys.time() ), "\n" )	
			}
			
			# pick mastTtis for the current user and the current burst
			mastTtisUserBurst <- mastTtisUser[ which( mastTtisUser$BURST_ID %in% burstId ), ]
	
			# session, burst and user id
			mastBurrUser[ burstId, "SESSION_ID" ] <- as.numeric( as.character( unique( mastTtisUserBurst$SESSION_ID ) ) )
			mastBurrUser[ burstId, "BURST_ID" ] <- burstId
			mastBurrUser[ burstId, "USER_ID" ] <- unique( mastTtisUserBurst[, userIdKpi ] )
			
			# timestamps and session/prev inter-burst durations
			mastBurrUser[ burstId, "START_TIME" ] <- min( mastTtisUserBurst$TIME, na.rm = T ) + unixTimeOffset
			mastBurrUser[ burstId, "CLOSE_TIME" ] <- max( mastTtisUserBurst$TIME, na.rm = T ) + unixTimeOffset + 0.001 # add 1 millisecond to include the duration of the last tti
			mastBurrUser[ burstId, "DURATION" ] <- mastBurrUser$CLOSE_TIME[ burstId ] - mastBurrUser$START_TIME[ burstId ] # seconds
			mastBurrUser[ burstId, "PREVEMP_DUR" ] <- mastTtisUserBurst[ which( mastTtisUserBurst$TIME %in% min( mastTtisUserBurst$TIME, na.rm = T ) ), "PREVEMP_DUR" ] / 1000 # seconds
			
			# user-level volume, last tti vol and res used
			mastBurrUser[ burstId, "VOL_DL" ] <- sum( mastTtisUserBurst$VOL_DL, na.rm = T ) # bytes
			mastBurrUser[ burstId, "LASTTTI_VOL_DL" ] <- mastTtisUserBurst$VOL_DL[ which( mastTtisUserBurst$TIME %in% max( mastTtisUserBurst$TIME, na.rm = T ) ) ] # bytes
			mastBurrUser[ burstId, "RES_DL" ] <- sum( mastTtisUserBurst$NALLOC, na.rm = T ) * 148 # REs (assuming each PRB uses 148 out of 168 REs for data)
		    mastBurrUser[ burstId, "PRBUTIL" ] <- mean( mastTtisUserBurst$PRBUTIL, na.rm = T)

			# thp time, sched activity and their ratios with sess dur (burst prob and sched prob respectively)
			mastBurrUser[ burstId, "THP_TIME_DL" ] <- round( 1000 * ( mastBurrUser$CLOSE_TIME[ burstId ] - mastBurrUser$START_TIME[ burstId ] - 0.001 ), digits = 0 ) # milliseconds (subtract 1 ms to exclude last tti)	
			mastBurrUser[ burstId, "SCHED_ACTIVITY_DL" ] <- nrow( mastTtisUserBurst ) - 1 # milliseconds (subtract last TTI, WARNING: this might be inconsistent with CTR definition)
			mastBurrUser[ burstId, "BURST_PROB_DL" ] <- mastBurrUser$THP_TIME_DL[ burstId ] / ( mastBurrUser$DURATION[ burstId ] * 1000 )
			mastBurrUser[ burstId, "SCHED_PROB_DL" ] <- mastBurrUser$SCHED_ACTIVITY_DL[ burstId ] / ( mastBurrUser$DURATION[ burstId ] * 1000 )
			
			# link-quality related metrics
			mastBurrUser[ burstId, "RANK_DL" ] <- ifelse( sum( mastTtisUserBurst$VOL_DL, na.rm = T ) %in% 0, NA, sum( mastTtisUserBurst$RANK_DL * mastTtisUserBurst$VOL_DL, na.rm = T ) / sum( mastTtisUserBurst$VOL_DL, na.rm = T ) )
			mastBurrUser[ burstId, "SPECF_DL" ] <- ifelse( mastBurrUser$RES_DL[ burstId ] %in% 0, 0, mastBurrUser$VOL_DL[ burstId ] * 8 / mastBurrUser$RES_DL[ burstId ] )	

			
			# prb util and thp
			mastBurrUser[ burstId, "PRB_UTIL_DL" ] <- 100 * sum( mastTtisUserBurst$NALLOC, na.rm = T ) / ( mastBurrUser$DURATION[ burstId ] * 1000 * numPrbsPerTti )
			mastBurrUser[ burstId, "THP_DL" ] <- ifelse( mastBurrUser$THP_TIME_DL[ burstId ] %in% 0, 0, ( mastBurrUser$VOL_DL[ burstId ] - mastBurrUser$LASTTTI_VOL_DL[ burstId ] ) * 8 / mastBurrUser$THP_TIME_DL[ burstId ] )
			
		}
		
		# add mastBurrUser to a list
		mastBurrUsers[[ match( user, userList ) ]] <- mastBurrUser
	}
	
	# concatenate mastBurrUser of all users into a single data frame
	mastBurr <- as.data.frame( data.table::rbindlist( mastBurrUsers ) )
	cat( paste( "Finished processing user", user, ":", match( user, userList ), "of", length( userList ), ": at", Sys.time() ), "\n" )

	# return mastBurr
	return( mastBurr )

}


################################################################
# MAST.CHNK

generateMasterChnkFromQxdmTtis <- function( mastTtis, minInterChunkTime, numPrbsPerTti, kpisInMaster, unixTimeOffset ) {
		
	# list of users
	userList <- unique( mastTtis[ , userIdKpi ] )
	
	# initialize list to contain mastBurrUsers
	mastChnkUsers <- NULL
	
	for( user in userList ) {
		
		cat( paste( "Started processing user", user, ":", match( user, userList ), "of", length( userList ), ": at", Sys.time() ), "\n" )
		
		# pick mastTtis for the current user
		mastTtisUser <- mastTtis[ which( mastTtis[ , userIdKpi ] %in% user ), ]
		
		# initialize mastChnkUser
		mastChnkUser <- data.frame( matrix( NA, nrow = max( mastTtisUser$CHUNK_ID, na.rm = T ), ncol = length( kpisInMaster ) ) )
		colnames( mastChnkUser ) <- kpisInMaster

		# compute kpis
		for( chunkId in seq( 1, nrow( mastChnkUser ) ) ) {
	
			if( chunkId %% 1000 == 1 ) {
				cat( paste( "...reached chunk", chunkId, "of", nrow( mastChnkUser ), "at", Sys.time() ), "\n" )	
			}
			
			# pick mastTtis for the current user and the current chunk
			mastTtisUserChunk <- mastTtisUser[ which( mastTtisUser$CHUNK_ID %in% chunkId ), ]
	
			# session, chunk and user id
			mastChnkUser[ chunkId, "SESSION_ID" ] <- as.numeric( as.character( unique( mastTtisUserChunk$SESSION_ID ) ) )
			mastChnkUser[ chunkId, "CHUNK_ID" ] <- chunkId
			mastChnkUser[ chunkId, "USER_ID" ] <- unique( mastTtisUserChunk[, userIdKpi ] )
			
			# timestamps and session/prev inter-chunk durations
			mastChnkUser[ chunkId, "START_TIME" ] <- min( mastTtisUserChunk$TIME, na.rm = T ) + unixTimeOffset
			mastChnkUser[ chunkId, "CLOSE_TIME" ] <- max( mastTtisUserChunk$TIME, na.rm = T ) + unixTimeOffset + 0.001 # add 1 millisecond to include the duration of the last tti
			mastChnkUser[ chunkId, "DURATION" ] <- mastChnkUser$CLOSE_TIME[ chunkId ] - mastChnkUser$START_TIME[ chunkId ] # seconds
			mastChnkUser[ chunkId, "PREVEMP_DUR" ] <- mastTtisUserChunk[ which( mastTtisUserChunk$TIME %in% min( mastTtisUserChunk$TIME, na.rm = T ) ), "PREVEMP_DUR" ] / 1000 # seconds
			
			# user-level volume, last tti vol and res used
			mastChnkUser[ chunkId, "VOL_DL" ] <- sum( mastTtisUserChunk$VOL_DL, na.rm = T ) # bytes
			mastChnkUser[ chunkId, "LASTTTI_VOL_DL" ] <- mastTtisUserChunk$VOL_DL[ which( mastTtisUserChunk$TIME %in% max( mastTtisUserChunk$TIME, na.rm = T ) ) ] # bytes
			mastChnkUser[ chunkId, "RES_DL" ] <- sum( mastTtisUserChunk$NALLOC, na.rm = T ) * 148 # REs (assuming each PRB uses 148 out of 168 REs for data)
            mastChnkUser[ chunkId, "PRBUTIL" ] <- mean( mastTtisUserChunk$PRBUTIL, na.rm = T)
			
			# thp time, sched activity and their ratios with sess dur (burst prob and sched prob respectively)
			mastChnkUser[ chunkId, "THP_TIME_DL" ] <- round( 1000 * ( mastChnkUser$CLOSE_TIME[ chunkId ] - mastChnkUser$START_TIME[ chunkId ] - 0.001 ), digits = 0 ) # milliseconds (subtract 1 ms to exclude last tti)	
			mastChnkUser[ chunkId, "SCHED_ACTIVITY_DL" ] <- nrow( mastTtisUserChunk ) - 1 # milliseconds (subtract last TTI, WARNING: this might be inconsistent with CTR definition)
			mastChnkUser[ chunkId, "BURST_PROB_DL" ] <- mastChnkUser$THP_TIME_DL[ chunkId ] / ( mastChnkUser$DURATION[ chunkId ] * 1000 )
			mastChnkUser[ chunkId, "SCHED_PROB_DL" ] <- mastChnkUser$SCHED_ACTIVITY_DL[ chunkId ] / ( mastChnkUser$DURATION[ chunkId ] * 1000 )
			
			# link-quality related metrics
			mastChnkUser[ chunkId, "RANK_DL" ] <- ifelse( sum( mastTtisUserChunk$VOL_DL, na.rm = T ) %in% 0, NA, sum( mastTtisUserChunk$RANK_DL * mastTtisUserChunk$VOL_DL, na.rm = T ) / sum( mastTtisUserChunk$VOL_DL, na.rm = T ) )
			mastChnkUser[ chunkId, "SPECF_DL" ] <- ifelse( mastChnkUser$RES_DL[ chunkId ] %in% 0, 0, mastChnkUser$VOL_DL[ chunkId ] * 8 / mastChnkUser$RES_DL[ chunkId ] )	

			# prb util and thp
			mastChnkUser[ chunkId, "PRB_UTIL_DL" ] <- 100 * sum( mastTtisUserChunk$NALLOC, na.rm = T ) / ( mastChnkUser$DURATION[ chunkId ] * 1000 * numPrbsPerTti )
			mastChnkUser[ chunkId, "THP_DL" ] <- ifelse( mastChnkUser$THP_TIME_DL[ chunkId ] %in% 0, 0, ( mastChnkUser$VOL_DL[ chunkId ] - mastChnkUser$LASTTTI_VOL_DL[ chunkId ] ) * 8 / mastChnkUser$THP_TIME_DL[ chunkId ] )
			
		}
		
		# add mastChnkUser to a list
		mastChnkUsers[[ match( user, userList ) ]] <- mastChnkUser
	}
	
	# concatenate mastChnkUser of all users into a single data frame
	mastChnk <- as.data.frame( data.table::rbindlist( mastChnkUsers ) )
	cat( paste( "Finished processing user", user, ":", match( user, userList ), "of", length( userList ), ": at", Sys.time() ), "\n" )

	# return mastBurr
	return( mastChnk )

}

################################################################
# MAST.SESS

generateMasterSessFromQxdmTtis <- function( mastBurr, mastChnk, numPrbsPerTti, kpisInMaster ) {

	# list of users
	userList <- unique( mastBurr$USER_ID )

	# initialize list to contain mastSessUsers
	mastSessUsers <- NULL
	   
	for( user in userList ) {

		cat( paste( "Started processing user", user, ":", match( user, userList ), "of", length( userList ), ": at", Sys.time() ), "\n" )

		# pick mastBurr for the current user
		mastBurrUser <- mastBurr[ which( mastBurr$USER_ID %in% user ), ]
	    mastChnkUser <- mastChnk[ which( mastChnk$USER_ID %in% user ), ]

		# initialize mastSessUser
		mastSessUser <- data.frame( matrix( NA, nrow = max( mastBurrUser$SESSION_ID, na.rm = T ), ncol = length( kpisInMaster ) + 1 ) )
		colnames( mastSessUser ) <- c(kpisInMaster, "THP_CHNK_DL")

		# initialize container for session ids that correspond to spurious session
		spuriousSessionIdList <- NULL
		
		# compute kpis
		for( sessionId in seq( 1, nrow( mastSessUser ) ) ) {

			if( sessionId %% 10 == 1 ) {
				cat( paste( "...reached session", sessionId, "of", nrow( mastSessUser ), "at", Sys.time() ), "\n" )	
			}
	
			# pick mastBurr, mastChnk for the current user and the current session
			mastBurrUserSession <- mastBurrUser[ which( mastBurrUser$SESSION_ID %in% sessionId ), ]
			mastChnkUserSession <- mastChnkUser[ which( mastChnkUser$SESSION_ID %in% sessionId ), ]
		
			# retain only bursts that are not spurious bursts at the start and the end of session
			nonSpuriousBurstIndices <- which( mastBurrUserSession$VOL_DL / 1024 >= 1 ) # 1 KB is the cutoff for calling out spurious portions at start and end
			nonSpuriousChunkIndices <- which( mastChnkUserSession$VOL_DL / 1024 >= 1 ) # 1 KB is the cutoff for calling out spurious portions at start and end

			if( length( nonSpuriousBurstIndices ) > 0 ) {

				# prev inter-burst duration
				mastSessUser[ sessionId, "PREVEMP_DUR" ] <- mastBurrUserSession[ which( mastBurrUserSession$START_TIME %in% min( mastBurrUserSession$START_TIME, na.rm = T ) ), "PREVEMP_DUR" ] # seconds
				
				# select the non-spurious bursts
				mastBurrUserSession <- mastBurrUserSession[ nonSpuriousBurstIndices[1] : tail( nonSpuriousBurstIndices, 1 ), ]
				mastChnkUserSession <- mastChnkUserSession[ nonSpuriousChunkIndices[1] : tail( nonSpuriousChunkIndices, 1 ), ]

				# session and user id
				mastSessUser[ sessionId, "SESSION_ID" ] <- as.numeric( as.character( unique( mastBurrUserSession$SESSION_ID ) ) )
				mastSessUser[ sessionId, "USER_ID" ] <- unique( mastBurrUserSession$USER_ID )
				
				# timestamps and session duration
				mastSessUser[ sessionId, "START_TIME" ] <- min( mastBurrUserSession$START_TIME, na.rm = T )	
				mastSessUser[ sessionId, "CLOSE_TIME" ] <- max( mastBurrUserSession$CLOSE_TIME, na.rm = T )
				mastSessUser[ sessionId, "DURATION" ] <- mastSessUser$CLOSE_TIME[ sessionId ] - mastSessUser$START_TIME[ sessionId ] # seconds
				
				# user-level volume, last tti vol and res used
				mastSessUser[ sessionId, "VOL_DL" ] <- sum( mastBurrUserSession$VOL_DL, na.rm = T ) # bytes
				mastSessUser[ sessionId, "LASTTTI_VOL_DL" ] <- mastBurrUserSession$VOL_DL[ which( mastBurrUserSession$START_TIME %in% max( mastBurrUserSession$START_TIME, na.rm = T ) ) ] # bytes
				mastSessUser[ sessionId, "RES_DL" ] <- sum( mastBurrUserSession$RES_DL, na.rm = T ) # REs 
                mastSessUser[ sessionId, "PRBUTIL" ] <- mean( mastBurrUserSession$PRBUTIL, na.rm = T)
				
				# thp time, sched activity and their ratios with sess dur (burst prob and sched prob respectively)
				mastSessUser[ sessionId, "THP_TIME_DL" ] <- sum( mastBurrUserSession$THP_TIME_DL, na.rm = T ) # milliseconds 
				mastSessUser[ sessionId, "SCHED_ACTIVITY_DL" ] <- sum( mastBurrUserSession$SCHED_ACTIVITY_DL ) # milliseconds
				mastSessUser[ sessionId, "BURST_PROB_DL" ] <- mastSessUser$THP_TIME_DL[ sessionId ] / ( mastSessUser$DURATION[ sessionId ] * 1000 )
				mastSessUser[ sessionId, "SCHED_PROB_DL" ] <- mastSessUser$SCHED_ACTIVITY_DL[ sessionId ] / ( mastSessUser$DURATION[ sessionId ] * 1000 )
				
				# link-quality related metrics
				mastSessUser[ sessionId, "RANK_DL" ] <- ifelse( sum( mastBurrUserSession$VOL_DL, na.rm = T ) %in% 0, NA, sum( mastBurrUserSession$RANK_DL * mastBurrUserSession$VOL_DL, na.rm = T ) / sum( mastBurrUserSession$VOL_DL, na.rm = T ) )
				mastSessUser[ sessionId, "SPECF_DL" ] <- ifelse( mastSessUser$RES_DL[ sessionId ] %in% 0, 0, mastSessUser$VOL_DL[ sessionId ] * 8 / mastSessUser$RES_DL[ sessionId ] )	
				
				# prb util and thp
				mastSessUser[ sessionId, "PRB_UTIL_DL" ] <- sum( mastBurrUserSession$PRB_UTIL_DL * mastBurrUserSession$DURATION, na.rm = T ) / sum( mastBurrUserSession$DURATION, na.rm = T )
				mastSessUser[ sessionId, "THP_DL" ] <- ifelse( mastSessUser$THP_TIME_DL[ sessionId ] %in% 0, 0, ( mastSessUser$VOL_DL[ sessionId ] - mastSessUser$LASTTTI_VOL_DL[ sessionId ] ) * 8 / mastSessUser$THP_TIME_DL[ sessionId ] )
                chunk_thptime_dl <- sum( mastChnkUserSession$THP_TIME_DL, na.rm = T) # milliseconds
                chunk_vol_dl <- sum( mastChnkUserSession$VOL_DL, na.rm = T ) # bytes
                chunk_lasttti_vol_dl <- mastChnkUserSession$VOL_DL[ which( mastChnkUserSession$START_TIME %in% max( mastChnkUserSession$START_TIME, na.rm = T) ) ] # bytes
                mastSessUser[ sessionId, "THP_CHNK_DL" ] <- ifelse( chunk_thptime_dl %in% 0, 0, ( chunk_vol_dl - chunk_lasttti_vol_dl ) * 8 / chunk_thptime_dl )
				#mastSessUser[ sessionId, "THP_CHNK_DL" ] <- mean( mastChnkUserSession$THP_DL )

			} else {
				
				# add the session id to the list of spurious session ids
				spuriousSessionIdList <- c( spuriousSessionIdList, sessionId )
			}			
			
		}
		
		# add sessions with less than 10 KB volume to the list of spurious sessions
		spuriousSessionIdList <- c( spuriousSessionIdList, which( mastSessUser$VOL_DL / 1024 < 10 ) )
		
		# remove spurious session records
		if( length( spuriousSessionIdList ) > 0 ) {
			cat( paste( "Removing", length( spuriousSessionIdList ), "spurious sessions from MAST.SESS with the following session IDs..." ), "\n" )
			cat( paste( spuriousSessionIdList, collapse = ", " ), "\n" )
			mastSessUser <- mastSessUser[ -spuriousSessionIdList, ]	
		}
		
		# add mastSessUser to a list
		mastSessUsers[[ match( user, userList ) ]] <- mastSessUser

	}

	# concatenate mastSessUser of all users into a single data frame
	mastSess <- as.data.frame( data.table::rbindlist( mastSessUsers ) )
	cat( paste( "Finished processing user", user, ":", match( user, userList ), "of", length( userList ), ": at", Sys.time() ), "\n" )

	# return mastSess
	return( mastSess )	

}

######################################################################################################################
### MAIN ###

#########################################
## SOURCE PIRAN_ROOT AND INPUT ARGUMENTS

PIRAN_ROOT <- Sys.getenv('PIRAN_ROOT')
args = commandArgs( trailingOnly = TRUE )

# PIRAN_ROOT <- "~/Documents/repos/piran"
# pathToData <- "/data/qxdm/threeVideo_9feb17"
# args <- c( paste0(pathToData, "/qxdm/out"), paste0(pathToData, "/qxdm/master"), 10 )

#########################################
## EXTRACT INPUT ARGUMENTS

# path to directory containing qxdm files
pathToQxdmOut <- paste0( args[1], "/" )

# path to directory containing master files
pathToQxdmMaster <- paste0( args[2], "/" )

# minimum inter-burst time (used to define/identify bursts)
minInterBurstTime <- as.numeric( as.character( args[3] ) )

# minimum inter-chunk time (used to define/identify bursts)
minInterChunkTime <- as.numeric( as.character( args[4] ) )

# kpi in qxdm_out.csv to use as user id
userIdKpi <- ifelse( length( args ) > 4, as.character( args[5] ), "RNTI" )

# total number of prbs per tti
numPrbsPerTti <- ifelse( length( args ) > 5, as.numeric( as.character( args[6] ) ), 50 )

# kpis in aggregated master files (mast.burr and mast.sess and mast.chnk)
kpisInMaster <- c( 		"SESSION_ID",
						"USER_ID",
						"START_TIME",
						"CLOSE_TIME",
						"DURATION",
						"PREVEMP_DUR",
						"VOL_DL",
						"LASTTTI_VOL_DL",
						"RES_DL",
						"THP_TIME_DL",
						"SCHED_ACTIVITY_DL",
						"BURST_PROB_DL",
						"SCHED_PROB_DL",
						"RANK_DL",
						"SPECF_DL",
						"PRB_UTIL_DL",
						"THP_DL",
                        "PRBUTIL" )

#########################################
## PRINT INPUT ARGUMENTS						
cat( "*************************************************** \n" )
cat( "INPUT ARGUMENTS \n" )
cat( "*************************************************** \n" )
cat( "Path to QXDM out: \n" )
cat( pathToQxdmOut, "\n" )
cat( "Path to QXDM master: \n" )
cat( pathToQxdmMaster, "\n" )
cat( "Minimum inter-burst time (in TTIs): \n" )
cat( minInterBurstTime, "\n" )
cat( "Minimum inter-chunk time (in TTIs): \n" )
cat( minInterChunkTime, "\n" )
cat( "KPI in qxdm_out to use as user ID: \n" )
cat( userIdKpi, "\n" )
cat( "Total PRBs per TTI on serving cell: \n" )
cat( numPrbsPerTti, "\n" )

#########################################
## GENERATE MAST FILES FOR EVERY QXDM.TTIS
cat( "*************************************************** \n" )
qxdmTtisFileNameList <- list.files( pathToQxdmOut, pattern = "QXDM.TTIS" )
cat( paste( "Found", length( qxdmTtisFileNameList ), "QXDM.TTIS files" ), "\n" )

registerDoParallel(cores=72)
foreach( i=1:length(qxdmTtisFileNameList) ) %dopar% {

    qxdmTtisFileName = qxdmTtisFileNameList[i]

	cat( "*************************************************** \n" )
	cat( paste( match( qxdmTtisFileName, qxdmTtisFileNameList ) ,"of", length( qxdmTtisFileNameList ), ":", qxdmTtisFileName ), "\n" )
	cat( "*************************************************** \n" )
	cat( paste( "Processing", qxdmTtisFileName, ":", match( qxdmTtisFileName, qxdmTtisFileNameList ), "of", length( qxdmTtisFileNameList ), ":", Sys.time() ), "\n" )
	generateMasterFilesFromQxdmTtis( pathToQxdmOut, pathToQxdmMaster, qxdmTtisFileName, kpisInMaster, minInterBurstTime, minInterChunkTime, userIdKpi, numPrbsPerTti )
}

cat( "*************************************************** \n" )
cat( "END OF PROCESSING. SUCCESS! \n" )
