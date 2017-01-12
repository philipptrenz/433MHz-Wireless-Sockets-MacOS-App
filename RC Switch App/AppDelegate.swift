//
//  AppDelegate.swift
//  RC Switch App
//
//  Created by Philipp Trenz on 10.01.17.
//  Copyright © 2017 Philipp Trenz. All rights reserved.
//

import Cocoa
import Foundation

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    
    @IBOutlet weak var menu: NSMenu!
    let statusItem = NSStatusBar.system().statusItem(withLength: NSSquareStatusItemLength)
    
    struct Device {
        var device: String
        var name: String
        var on: Bool
    }
    
    let BASE_URL = "http://192.168.0.11"
    
    var deviceList = [Device]()
    var menuItemDeviceMapper = [Int: Device]()
    var errorMessage = "No connection"
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let icon = NSImage(named: "rc-switch-app")
        icon?.isTemplate = true // best for dark mode
        statusItem.image = icon
        statusItem.menu = menu
        menu.delegate = self
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    
    // Gets called when menu is about to open
    // If returns an integer,
    func numberOfItems(in menu: NSMenu) -> Int {
        var waiting = true
        getList {
            devices in
            self.deviceList = devices as! [AppDelegate.Device]
            waiting = false
        }
        while(waiting){ wait() }
        if deviceList.count == 0 {
            return 1
        }
        return deviceList.count
    }
    
    func menu(_ menu: NSMenu, update item: NSMenuItem, at index: Int, shouldCancel: Bool) -> Bool {
        if (index == 0 && deviceList.count == 0) {
            item.title = self.errorMessage
            item.isEnabled = false
            item.action = nil
            return true
        }
        
        let rcswitch = deviceList[index]
        item.title = "Turn " + rcswitch.name + (rcswitch.on ? " off" : " on")
        item.target = self
        item.action = rcswitch.on ? #selector(switchOff(sender:)) : #selector(switchOn(sender:))
        
        item.identifier = rcswitch.device
        
        return true
    }

    /* -------------------------------------------------------------------- */
    
    
    func switchOn(sender: NSMenuItem) {
        if let device = sender.identifier {
            let session = URLSession.shared
            // url-escape the query string we're passed
            let url = NSURL(string: "\(BASE_URL)/\(device)/on")
            let task = session.dataTask(with: url! as URL) { data, response, err in
                // first check for a hard error
                if let error = err {
                    NSLog("433 py api error: \(error)")
                }
                
                // then check the response code
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200: // all good!
                        let dataString = NSString(data: data!, encoding: String.Encoding.utf8.rawValue) as! String
                        NSLog("\(device) \(dataString)")
                    case 401: // unauthorized
                        NSLog("433 py api returned an 'unauthorized' response.")
                    case 550: // unauthorized
                        NSLog("433 py api returned an 'unauthorized' response.")
                    default:
                        NSLog("433 py api response: %d %@", httpResponse.statusCode, HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                    }
                }
            }
            task.resume()
        }
    }
    
    func switchOff(sender: NSMenuItem) {
        if let device = sender.identifier {
            let session = URLSession.shared
            // url-escape the query string we're passed
            let url = NSURL(string: "\(BASE_URL)/\(device)/off")
            let task = session.dataTask(with: url! as URL) { data, response, err in
                // first check for a hard error
                if let error = err {
                    NSLog("433 py api error: \(error)")
                }
                
                // then check the response code
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200: // all good!
                        let dataString = NSString(data: data!, encoding: String.Encoding.utf8.rawValue) as! String
                        NSLog("\(device) \(dataString)")
                    case 401: // unauthorized
                        NSLog("433 py api returned an 'unauthorized' response.")
                    case 550: // unauthorized
                        NSLog("433 py api returned an 'unauthorized' response.")
                    default:
                        NSLog("433 py api response: %d %@", httpResponse.statusCode, HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                    }
                }
            }
            task.resume()
        }
    }
    
    /* -------------------------------------------------------------------- */
    
    func getList(completionHandler: @escaping (_ devices: NSArray) -> ()) {
        
        // url-escape the query string we're passed
        let url = NSURL(string: "\(BASE_URL)/list")
        
        let requestJson = [
            "secret": "test"
            ] as [String: String]
        
        var request = URLRequest(url: url as! URL)
        request.httpMethod = "POST"
        request.httpBody = try! JSONSerialization.data(withJSONObject: requestJson, options: [])
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let urlconfig = URLSessionConfiguration.default
        urlconfig.timeoutIntervalForRequest = 1         // timeout 1 s
        urlconfig.timeoutIntervalForResource = 3
        let session = URLSession(configuration: urlconfig)
        let task = session.dataTask(with: request) { data, response, err in

            if let error = err as? NSError, error.domain == NSURLErrorDomain {
                self.errorMessage = "No connection"
                completionHandler(NSArray())    // return empty
            } else if let httpResponse = response as? HTTPURLResponse {
                
                switch httpResponse.statusCode {
                    
                case 200: // all good!
                    
                    let jsonData: NSArray = try! (JSONSerialization.jsonObject(with: data!, options:.mutableContainers) as? NSArray)!
                    
                    //NSLog("\(jsonData)")
                    
                    var deviceList = [Device]()
                    
                    for object in jsonData {
                        // access all objects in array
                        let new = object as! [String: String]   // cast to dictionary
                        
                        let device = new["device"]
                        let name = new["name"]
                        let on = (new["state"] == "on")
                        
                        let newDevice = Device(
                            device: device!,
                            name: name!,
                            on: on
                        )
                        deviceList.append(newDevice)
                        //NSLog("Got \(newDevice.name) (\(newDevice.device))")
                    }
                    self.errorMessage = "No sockets configured"
                    completionHandler(deviceList as NSArray)
                    
                default:
                    self.errorMessage = "No connection"
                    completionHandler(NSArray())    // return empty
                    NSLog("433 py api response: %d %@", httpResponse.statusCode, HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                }
            }
        }
        task.resume()
    }
}
