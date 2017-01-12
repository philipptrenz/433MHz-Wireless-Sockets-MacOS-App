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
    
    let statusItem = NSStatusBar.system().statusItem(withLength: NSSquareStatusItemLength)
    
    @IBOutlet weak var menu: NSMenu!
    @IBOutlet weak var ipAddressWindow: NSWindow!
    @IBOutlet weak var IpAddressTextfield: NSTextFieldCell!
    @IBOutlet weak var SecretTextfield: NSTextFieldCell!
    
    let defaults = UserDefaults.standard
    var deviceList = [Device]()
    var errorMessage = "No connection"
    let keyForBaseUrl = "base_url"
    let keyForSecret = "secret"
    
    struct Device {
        var device: String
        var name: String
        var on: Bool
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // initialize status bar icon and menu
        let icon = NSImage(named: "rc-switch-app")
        icon?.isTemplate = true // best for dark mode
        statusItem.image = icon
        statusItem.menu = menu
        menu.delegate = self
        
        // is url to api and secret are not already set, show window for entering
        if defaults.string(forKey: keyForBaseUrl) == nil || defaults.string(forKey: keyForSecret) == nil {
            ipAddressWindow.makeKeyAndOrderFront(nil) // open window
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Nothing to do
    }
    
    // When save button got pressed validate and save inputs and close window
    @IBAction func saveIpAddressFromWindow(_ sender: NSButtonCell) {
        var address = IpAddressTextfield.stringValue
        let secret = SecretTextfield.stringValue != "" ? SecretTextfield.stringValue : "test"
        
        if !address.hasPrefix("http://") || !address.hasPrefix("https://") {
            address = "http://"+address
        }
        testURL(urlString: address, secret: secret){
            isOkay in
            if (isOkay) {
                self.defaults.setValue(address, forKey: self.keyForBaseUrl)
                self.defaults.setValue(secret, forKey: self.keyForSecret)
                self.ipAddressWindow.close()
            } else {
                self.IpAddressTextfield.stringValue = ""
                self.SecretTextfield.stringValue = ""
            }
        }
        
    }

    
    // Gets called when menu is about to open
    // If returns an integer
    func numberOfItems(in menu: NSMenu) -> Int {
        var waiting = true
        getList {
            devices in
            self.deviceList = devices as! [AppDelegate.Device]
            waiting = false
        }
        while(waiting){ _ = wait() }
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
        if let device = sender.identifier, let BASE_URL = defaults.string(forKey: keyForBaseUrl){
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
        if let device = sender.identifier, let BASE_URL = defaults.string(forKey: keyForBaseUrl) {
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
        
        if let BASE_URL = defaults.string(forKey: keyForBaseUrl), let secret = defaults.string(forKey: keyForSecret) {
            // url-escape the query string we're passed
            let url = NSURL(string: "\(BASE_URL)/list")
            
            let requestJson = [
                "secret": secret
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
    
    func testURL(urlString: String, secret: String, completionHandler: @escaping (_ canConnectToServer: Bool) -> ()) {
        var request: URLRequest!
        //if let testRequest = URLRequest(url: (NSURL(string: "\(urlString)/list") as! URL)) {
        if let url =  NSURL(string: "\(urlString)/list") {
            request = URLRequest(url: url as URL)
        } else {
            completionHandler(false)
        }
        
        let requestJson = [
            "secret": secret
            ] as [String: String]
        
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
                completionHandler(false)    // return empty
            } else if let httpResponse = response as? HTTPURLResponse {
                
                switch httpResponse.statusCode {
                    
                case 200: // all good!
                    if (try? JSONSerialization.jsonObject(with: data!, options:.mutableContainers) as? NSArray) != nil {
                        completionHandler(true)
                    }
                    completionHandler(false)
                    
                default:
                    self.errorMessage = "No connection"
                    completionHandler(false)
                }
            }
        }
        task.resume()
        
    }
}
