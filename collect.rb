#coding: utf-8
require "open-uri"
require "nokogiri"
require "date"
require "active_record"
require './pool'
# 数据库连接
ActiveRecord::Base.establish_connection(adapter: "mysql2", host: "localhost", database: "c8591", username: "root")
# 数据模型
class Post < ActiveRecord::Base
end

class GameCollection
  @@gamelist = {}
  @@gameservers = {}
  @@gameservernames = {}
  @nextpage = true
  # 获取游戏列表
  def GameCollection.getGamelist
    url = "http://static.8591.com.tw/min/?g=js-head"
    open(url) do |data|
      html = data.read
      matchedGameStr = /arrGame=\'(.*?)\'/.match(html)
      matchedGameStr[1].split('|').each do |game|
        f = game.split('#')
        gid = f[1].to_i
        @@gamelist[gid] = f[2]
        matchedservers = /a\[\'#{gid}\'\]=\[(.*?)\]/.match(html)
        @@gameservers[gid] = matchedservers[1].delete("'").split(',') if matchedservers
        if matchedservers
          matchedservernames = /b\[\'#{gid}\'\]=\[(.*?)\]/.match(html)
          @@gameservernames[gid] = matchedservernames[1].delete("'").split(',')
        end
      end
    end
    @@gamelist
  end

  def collect gid
    gservers = @@gameservers[gid]
    if gservers
      gservers.each_with_index do |gserver,index|
        c gid, 0, gserver, index
      end
    else
      c gid
    end
  end

  def c gid,  firstRow = 0, gserver = nil , serverindex = nil
    url = "http://www.8591.com.tw/index.php?firstRow=#{firstRow}&totalRows=300&searchServer=#{gserver}&searchGame=#{gid}&TStatus=8&module=wareList&action=sellList"
    if gserver.nil?
      url = "http://www.8591.com.tw/index.php?firstRow=#{firstRow}&totalRows=300&searchGame=#{gid}&TStatus=8&module=wareList&action=sellList"
    end
    puts url
    doc = Nokogiri::HTML(open(url))
    doc.css('div.NameRight').each do |temp|
      date = temp.css('div.Date')[0].content
      if date == "2天前"
        @nextpage = false
        return
      end
      if date == "1天前"
        title = temp.css("a.showTitle")[0].attr("title")
        type = temp.css("span.kindType")[0].content.delete('物品種類：')
        price = temp.css('div.Price')[0].content.delete(' 元').delete(',')
        post = Post.new(title: title, gname: @@gamelist[gid],  gid: gid, kindtype: type, price: price, postdate: (DateTime.now - 1).strftime('%Y-%m-%d'))
        post.servername = @@gameservernames[gid][serverindex] if serverindex
        post.save
      end
    end
    if firstRow < 270 and @nextpage
      firstRow += 30
      c gid, firstRow, gserver, serverindex
    end
  end
end

pool = Thread::Pool.new(20)
GameCollection.getGamelist.keys.each do |gid|
  pool.process {
    puts gid
    gc = GameCollection.new
    gc.collect gid
  }
end
pool.shutdown
