//
//  ViewController.swift
//  OnDeallocateXDemo
//
//  Created by Siarhei Ladzeika on 5/30/18.
//  Copyright © 2018 BPMobile. All rights reserved.
//

import UIKit
import OnDeallocateX

class ViewController: UIViewController {
    
    deinit {
        print("deinit")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.
        onWillDeallocate {
            print("will deallocate")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

