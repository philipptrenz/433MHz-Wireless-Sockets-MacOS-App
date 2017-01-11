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
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let icon = NSImage(named: "rc-switch-app")
        icon?.isTemplate = true // best for dark mode
        statusItem.image = icon
        statusItem.menu = menu
        menu.delegate = self
        
        let menuItem = NSMenuItem()
        menuItem.title = "No devices configured"
        menuItem.isEnabled = false
        self.menu.addItem(menuItem)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        getList {
            devices in
            // if device changed (state, name, new devices added, ...)
            var reinitiate = false
            
            // if devices added or deleted
            if (devices.count != self.deviceList.count) {
                reinitiate = true
            } else {
                
                // update titles
                for i in 0 ..< devices.count {
                    let devOld = self.deviceList[i]
                    let devNew = devices[i] as! Device
                    // if device id is different
                    if (devOld.device != devNew.device) {
                        reinitiate = true
                        break
                    } else {
                        // get menuItem with value of device
                        let items = self.menu.items
                        // find correct item
                        for i in 0 ..< items.count {
                            let item = items[i]
                            // set title new
                            if item.title.contains(devOld.name) {
                                item.title = "Turn " + devNew.name + (devNew.on ? " off" : " on")
                            }
                        }
                    }
                }
                
                self.deviceList = devices as! [AppDelegate.Device]
            }
            
            // reinitialize all menu items
            if (reinitiate) {
                // reinitiate menu items
                self.deviceList = devices as! [AppDelegate.Device]
                self.menu.removeAllItems()
                self.menuItemDeviceMapper.removeAll()
                
                if (devices.count == 0) {
                    let menuItem = NSMenuItem()
                    menuItem.title = "No device configured"
                    menuItem.isEnabled = false
                    self.menu.addItem(menuItem)
                } else {
                    for rcswitch in devices {
                        let rcswitch = rcswitch as! Device
                        let menuItem = NSMenuItem()
                        menuItem.title = "Turn " + rcswitch.name + (rcswitch.on ? " off" : " on")
                        menuItem.target = self
                        menuItem.action = #selector(self.switchit(sender:))
                        menuItem.isEnabled = true
                        //menuItem.keyEquivalent = "t"
                        self.menu.addItem(menuItem)
                        self.menuItemDeviceMapper[menuItem.hash] = rcswitch
                    }
                }
                
            }
        }
    }
    
    func switchit(sender: AnyObject) {
        let sender = sender as! NSMenuItem
        NSLog("selector works!")
        
        if let rcswitch = menuItemDeviceMapper[sender.hash]{
            if rcswitch.on {
                switchOff(device: (rcswitch.device))
            } else {
                switchOn(device: rcswitch.device)
            }
        }
        
    }
    

    
    
    /* -------------------------------------------------------------------- */
    
    
    func switchOn(device: String) {
        NSLog("turning \(device) on")
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
                    NSLog(dataString)
                case 401: // unauthorized
                    NSLog("433 py api returned an 'unauthorized' response.")
                case 550: // unauthorized
                    NSLog("433 py api returned an 'unauthorized' response.")
                default:
                    NSLog("weather api returned response: %d %@", httpResponse.statusCode, HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                }
            }
        }
        task.resume()
    }
    
    func switchOff(device: String) {
        NSLog("turning \(device) off")
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
                    NSLog(dataString)
                case 401: // unauthorized
                    NSLog("433 py api returned an 'unauthorized' response.")
                case 550: // unauthorized
                    NSLog("433 py api returned an 'unauthorized' response.")
                default:
                    NSLog("weather api returned response: %d %@", httpResponse.statusCode, HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                }
            }
        }
        task.resume()
    }
    
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
        
        let task = URLSession.shared.dataTask(with: request) { data, response, err in
            // first check for a hard error
            if let error = err {
                NSLog("433 py api error: \(error)")
            }
            
            // then check the response code
            if let httpResponse = response as? HTTPURLResponse {
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
                    completionHandler(deviceList as NSArray)
                    
                    
                case 401: // unauthorized
                    NSLog("433 py api returned an 'unauthorized' response.")
                case 550: // unauthorized
                    NSLog("433 py api returned an 'unauthorized' response.")
                case 1004: // could not connect to the server
                    NSLog("No connection to the server.")
                default:
                    NSLog("433 py api response: %d %@", httpResponse.statusCode, HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                }
            }
        }
        task.resume()
    }
}
