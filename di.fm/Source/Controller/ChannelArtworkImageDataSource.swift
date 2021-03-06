//
//  ChannelArtworkImageDataSource.swift
//  di.fm
//
//  Created by Charles Magahern on 5/8/16.
//  Copyright © 2016 zanneth. All rights reserved.
//

import Foundation
import UIKit

class ChannelArtworkImageDataSource
{
    typealias ChannelArtworkCallback = (UIImage?, NSError?) -> (Void)
    
    var server: AudioAddictServer?
    
    private var _cache:                      [Int : UIImage] = [:] // channel identifiers -> images
    private var _pendingCallbacks:           [Int : [ChannelArtworkCallback]] = [:] // channel identifiers -> callbacks
    private var _serialQueue:                dispatch_queue_t
    
    init()
    {
        _serialQueue = dispatch_queue_create("ChannelArtworkImageDataSource", DISPATCH_QUEUE_SERIAL)
    }
    
    func loadChannelArtworkImage(channel: Channel, size: CGSize, completion: ChannelArtworkCallback)
    {
        dispatch_async(_serialQueue) {
            if let cachedImage = self._cache[channel.identifier] {
                completion(cachedImage, nil)
            } else if (self._pendingCallbacks[channel.identifier] != nil) {
                self._pendingCallbacks[channel.identifier]!.append(completion)
            } else {
                self._onQueueBeginLoad(channel, size: size, completion: completion)
            }
        }
    }
    
    // MARK: Internal
    
    internal func _onQueueBeginLoad(channel: Channel, size: CGSize, completion: ChannelArtworkCallback)
    {
        guard let server = self.server else {
            let err = NSError.difmError(.ConfigurationError, description: "no server configured for artwork data source")
            completion(nil, err)
            return
        }
        
        _pendingCallbacks[channel.identifier] = [completion]
        
        server.loadChannelArtwork(channel.image, size: size) { (imageData: NSData?, error: NSError?) -> (Void) in
            dispatch_async(self._serialQueue, {
                var loadedImage: UIImage? = nil
                
                if (imageData != nil) {
                    loadedImage = UIImage(data: imageData!)
                    self._cache[channel.identifier] = loadedImage
                }
                
                for callback in self._pendingCallbacks[channel.identifier]! {
                    callback(loadedImage, error)
                }
                
                self._pendingCallbacks.removeValueForKey(channel.identifier)
            })
        }
    }
}
