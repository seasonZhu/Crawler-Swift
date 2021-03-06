//
//  AniamtionListController.swift
//  Crawler-Swift
//
//  Created by season on 2019/5/21.
//  Copyright © 2019 season. All rights reserved.
//

import UIKit

class AniamtionListController: UITableViewController {
    
    var seedDownloadInfos: [SeedDownloadInfo?]?
    
    var isUseHashAsTitle = false

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "reuseIdentifier")
        tableView.rowHeight = 66
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return seedDownloadInfos?.count ?? 0
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)
        
        if let seedDownloadInfos = seedDownloadInfos, seedDownloadInfos.count >= indexPath.row {
            let seedDownloadInfo = seedDownloadInfos[indexPath.row]
            cell.textLabel?.text = seedDownloadInfo?.title
            cell.textLabel?.numberOfLines = 0
        }
        
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        if let seedDownloadInfos = seedDownloadInfos, seedDownloadInfos.count >= indexPath.row {
            
            Hud.showWait(message: "正在下载种子", autoClear: false)
            
            let seedDownloadInfo = seedDownloadInfos[indexPath.row]
            //  写入的时候 如果使用动画的title即一大串中文字符串的时候老是莫名出错,如果将hash作为title则不会出现这样的问题
            guard let urlString = seedDownloadInfo?.url, let title = isUseHashAsTitle ? seedDownloadInfo?.hash : seedDownloadInfo?.title else {
                return
            }
            
            let seed = title + ".torrent"
            //  打开iTunes中的文件共享 就是共享的Documents文件夹 可以看见里面下载的种子
            let documents = NSHomeDirectory() + "/Documents/"
            
            // 已包含文件就不下载
            let fileNames = try? FileManager.default.contentsOfDirectory(atPath: documents)
            if let names = fileNames, names.contains(seed) {
                return
            }
            
            // 下载
            guard let url = URL(string: urlString) else {
                return
            }
            
            DispatchQueue.global().async {
                guard let data = try? Data(contentsOf: url) else {
                    return
                }
                
                DispatchQueue.main.async {
                    
                    Hud.clear()
                    
                    let path = documents + seed
                    print(path)
                    let fileURL = URL(fileURLWithPath: path)
                    
                    do {
                        try data.write(to: fileURL)
                        Hud.showMessage(message: fileURL.absoluteString)
                    }catch {
                        print(error)
                        let errorMessage = (error as NSError).domain
                        Hud.showMessage(message: errorMessage)
                    }
                    
                }
            }
        }
    }
}
