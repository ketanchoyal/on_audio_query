import Flutter
import MediaPlayer

class OnPodcastsQuery {
    var args: [String: Any]
    var result: FlutterResult
    
    init(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // To make life easy, add all arguments inside a map.
        self.args = call.arguments as! [String: Any]
        self.result = result
    }
    
    func queryPodcasts() {
        // The sortType.
        let sortType = args["sortType"] as? Int ?? 0
        
        // Choose the type(To match android side, let's call "cursor").
        let cursor = MPMediaQuery.podcasts()
        // Using native sort from [IOS] you can only use the [Title], [Album] and
        // [Artist]. The others will be sorted "manually" using [formatPodcastList] before
        // send to Dart.
        cursor.groupingType = checkSongSortType(sortType: sortType) // TODO perhaps implement custom function for this
        
        // This filter will avoid podcasts outside phone library(cloud).
        let cloudFilter = MPMediaPropertyPredicate.init(
            value: false,
            forProperty: MPMediaItemPropertyIsCloudItem
        )
        cursor.addFilterPredicate(cloudFilter)
        
        // We cannot "query" without permission so, just return a empty list.
        let hasPermission = SwiftOnAudioQueryPlugin().checkPermission()
        if hasPermission {
            // Query everything in background for a better performance.
            loadPodcasts(cursor: cursor)
        } else {
            // There's no permission so, return empty to avoid crashes.
            result([])
        }
    }
    
    private func loadPodcasts(cursor: MPMediaQuery!) {
        DispatchQueue.global(qos: .userInitiated).async {
            var listOfPodcasts: [[String: Any?]] = Array()
            
            // For each item(podcast) inside this "cursor", take one and "format"
            // into a [Map<String, dynamic>], all keys are based on [Android]
            // platforms so, if you change some key, will have to change the [Android] too.
            for podcast in cursor.items! {
                // If the podcast file don't has a assetURL, is a Cloud item.
                if !podcast.isCloudItem && podcast.assetURL != nil {
                    let podcastData = loadPodcastItem(podcast: podcast)
                    listOfPodcasts.append(podcastData)
                }
            }
            
            // After finish the "query", go back to the "main" thread(You can only call flutter
            // inside the main thread).
            DispatchQueue.main.async {
                // Here we'll check the "custom" sort and define a order to the list.
                let finalList = formatPodcastList(args: self.args, allPodcasts: listOfPodcasts)
                self.result(finalList)
            }
        }
    }
}
