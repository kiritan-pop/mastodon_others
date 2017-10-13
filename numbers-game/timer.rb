# coding: utf-8
require 'mastodon'
require 'nokogiri'
require 'json'
require 'highline/import'
require 'oauth2'
require 'dotenv'
require 'pp'
require 'clockwork'
require 'fileutils'
include Clockwork


# --- config
Dotenv.load
TL='user'
MASTODON_URL = ENV["MASTODON_URL"]
INSTANCE= MASTODON_URL[8..MASTODON_URL.length-1]
TOKEN = ENV["MASTODON_ACCESS_TOKEN"]
JSON_PATH = "json/"
VOTE_FILE_PATH = "vote.json"
SCORE_FILE_PATH = "score.json"
TSCORE_FILE_PATH = "t_score.json"
GAME_FILE_PATH = "game.json"
NAME_FILE_PATH = "name.json"
RANK_FILE_PATH = "rank.json"

ANA_SCORE_PATH = "ana_score.json"
ANA_VOTE_CNT_PATH = "ana_vote_cnt.json"
ANA_VOTE_NUM_PATH = "ana_vote_num.json"
ANA_SCORE_CNT_PATH = "ana_score_cnt.json"

FEVER_VAL = 10   #フィーバータイムの加算

C_NONE = "none@none@none"
DEFAULT_BOT_ID = 'kiri_bot01'
KIRI_GAME_TAG = "\n #きりゲーム #数取りゲーム"

if !ENV["BOT_ID"]
  ENV["BOT_ID"] = DEFAULT_BOT_ID
  File.open(".env","a+") do |f|
    f.write "BOT_ID = '#{ENV["BOT_ID"]}'\n"
  end
end

if !ENV["GAME_TIMER"]
  ENV["GAME_TIMER"] = 3.to_s
  File.open(".env","a+") do |f|
    f.write "GAME_TIMER = '#{ENV["GAME_TIMER"]}'\n"
  end
end


START_GAME_SPOILER = "数取りゲームを始めるよー！"
GAME_MESSAGE = "の中から好きな数字を選んでねー！\n・リプかＤＭで返信してねー！\n・誰とも被らなければその数字があなたの得点になるよ！"

NOTICE_GAME_SPOILER = "数取りゲーム、残り１分だよー！"
END_GAME_MESSAGE = "数取りゲーム終了ー！"

# --- debug switch  true false
VERB = false

#####################################################
#トゥートメソッド
def exe_toot(body,acct = nil,spoiler_text = nil)

  client = Mastodon::REST::Client.new(base_url: ENV["MASTODON_URL"],
                                      bearer_token: ENV["MASTODON_ACCESS_TOKEN"])

  acct = "@"+acct if acct != nil

  if  acct == nil
    visibility = "public"
  else
    visibility = "direct"
  end

  puts "1:body:#{body}","acct:#{acct}" if VERB

  client.create_status_kiri( "#{acct} #{body}"+KIRI_GAME_TAG  , visibility ,spoiler_text)

  puts "2:body:#{body}","acct:#{acct}" if VERB

#  sleep(3)
end

#####################################################
# 分析処理
def analyze()

  h_score = {}        #総得点
  h_vote_cnt = {}   #投票回数
  h_vote_num = {}     #投票人数
  h_score_cnt = {}  #得点回数

  Dir.glob("**/*vote.json").each{|file_path|

    tmp_score     = {}
    tmp_vote_cnt  = {}
    tmp_score_cnt = {}


  #投票ファイルをすべて調査！
    h_vote = open(file_path) do |io|
      JSON.load(io)
    end

    h_vote.each{|key,value|

      #総得点の元ネタ
      if tmp_score[value] == nil
        tmp_score[value] = value.to_i
      else
        tmp_score[value] = 0
      end

      #投票回数の元ネタ
      tmp_vote_cnt[value] = 1

      #投票人数
      if h_vote_num[value] == nil
        h_vote_num[value] = 1
      else
        h_vote_num[value] += 1
      end

      #得点回数の元ネタ
      if tmp_score_cnt[value] == nil
        tmp_score_cnt[value] = 1
      else
        tmp_score_cnt[value] = 0
      end

    }

    #総得点累積
    tmp_score.each{|key,value|
      if  h_score[key] == nil
        h_score[key] = value.to_i
      else
        h_score[key] += value.to_i
      end
    }
    #ファイル出力
    open( JSON_PATH + ANA_SCORE_PATH, 'w') do |io|
      JSON.dump(h_score, io)
    end

    #投票回数累積
    tmp_vote_cnt.each{|key,value|
      if  h_vote_cnt[key] == nil
        h_vote_cnt[key] = value.to_i
      else
        h_vote_cnt[key] += value.to_i
      end
    }
    #ファイル出力
    open( JSON_PATH + ANA_VOTE_CNT_PATH, 'w') do |io|
      JSON.dump(h_vote_cnt, io)
    end

    #投票人数
    #ファイル出力
    open( JSON_PATH + ANA_VOTE_NUM_PATH, 'w') do |io|
      JSON.dump(h_vote_num, io)
    end

    #得点回数累積
    tmp_score_cnt.each{|key,value|
      if  h_score_cnt[key] == nil
        h_score_cnt[key] = value.to_i
      else
        h_score_cnt[key] += value.to_i
      end
    }
    #ファイル出力
    open( JSON_PATH + ANA_SCORE_CNT_PATH, 'w') do |io|
      JSON.dump(h_score_cnt, io)
    end

  }
end


#####################################################
# 動作
handler do |job|
  case job
  when "main"

    #jsonフォルダなければ作るー！
    Dir.mkdir(JSON_PATH) unless  Dir.exist?(JSON_PATH)

    #ゲーム情報ファイルがなかったら作るー！
    h_game = {}
    if File.exist?(JSON_PATH  + GAME_FILE_PATH) == false
      File.open(JSON_PATH  + GAME_FILE_PATH,'w') do |io|
        h_game = {"game_season"=>1,"game_number"=>1,"game_status"=>"EXEC","min"=>1,"max"=>13,"game_mode"=>"NORM"}
        JSON.dump(h_game,io)
      end
    else

    #ゲーム情報の設定・更新
      h_game = open(JSON_PATH  + GAME_FILE_PATH) do |io|
        JSON.load(io)
      end

      File.open(JSON_PATH  + GAME_FILE_PATH,'w') do |io|

        begin

          #2回目以降のゲーム情報の設定（期変わりの初回はゲームファイル作成済み）
          if  h_game["game_number"] >= 1

            #ゲームモード設定！
            max_score = 0
            #合計スコアファイルを読み込むー！
            h_t_score = open(JSON_PATH  + TSCORE_FILE_PATH) do |io|
              JSON.load(io)
            end

            h_t_score.each{|key,value|
              max_score = value if max_score < value
            }

            if h_game["game_mode"] != "NKYS"     #なかよしタイムは継続！
                if  max_score >= 70
                  h_game["game_mode"] = "HIGH"  #70点以上の人がいたら！
                else
                  h_game["game_mode"] = "NORM"  #70点以上の人がいなくなったら！
                end
            else
                if  max_score >= 70
                  h_game["game_mode"] = "NKHI"  #70点以上の人がいたら！
                else
                  h_game["game_mode"] = "NKYS"  #70点以上の人がいなくなったら！
                end
            end

            #前回投票数から数値min～max設定
            if  h_game["game_status"] == "DONE"
              h_vote = open( JSON_PATH  + "ZZZ_#{h_game["game_number"]}_" +  VOTE_FILE_PATH) do |io|
                JSON.load(io)
              end

              #前回投票数より自動設定
              h_game["min"] = 1
              h_game["max"] = (h_vote.size + 1) / 2 + 5

              #フィーバータイムは範囲拡大
              if h_game["game_mode"] == "HIGH"  || h_game["game_mode"] == "NKHI"
                h_game["min"] += FEVER_VAL
                h_game["max"] += FEVER_VAL + 5
              end

            end

          end

        #前回正常終了ならば＋１するけど、EXECのままだったら＋１しないよー！
          h_game["game_number"] = h_game["game_number"] + 1 if  h_game["game_status"] == "DONE"
          h_game["game_status"] = "EXEC"

        rescue => e
          puts "error 000"
          puts e
        end

      #ゲームファイル更新
        JSON.dump(h_game,io)
      end
    end

  #チャンスモード！
    fever_txt = ""
    fever_txt = "💫FEVER💫" if h_game["game_mode"] == "HIGH"
    fever_txt = "💚仲良し💚" if h_game["game_mode"] == "NKYS"  #なかよしタイム追加
    fever_txt = "💖仲良しFEV💖" if h_game["game_mode"] == "NKHI"  #なかよしフィーバータイム追加

  #ゲーム開始トゥート！
    exe_toot("・#{h_game["min"]}～#{h_game["max"]}"+GAME_MESSAGE+"\n⚠️制限時間は約#{ENV["GAME_TIMER"]}分だよー！",nil,"【第#{h_game["game_season"]}期】第#{h_game["game_number"]}回"+START_GAME_SPOILER+fever_txt)

  #フィーバー説明トゥート！
#    if  h_game["game_mode"] == "HIGH"
#      sleep(3)
#      exe_toot("説明しよう！！スコア70点以上の人がいるとフィーバータイムに突入だよー！\nフィーバータイムは以下の特徴があるよー！\n ・得点が大きくなるよー！\n ⚠投票が被るとその得点分減点！\n ・ハイリスク、ハイリターンだよー！",nil,"フィーバータイムだよー！")
#    end

  #なかよしタイム説明トゥート！
#    if  h_game["game_mode"] == "NKYS"
#      sleep(3)
#      exe_toot("説明しよう！！なんとなくの気分でなかよしモードに突入だよー！\nなかよしタイムは以下の特徴があるよー！\n ・投票が被ってもみんなで得点を分け合うよー！\n ・端数は投票の早かった人（多分…）に分配されるよー",nil,"なかよしタイムだよー！")
#    end

  #フィーバー説明トゥート！
    if  h_game["game_mode"] == "NKHI"
      sleep(3)
      exe_toot("説明しよう！！仲良しモードでスコア70点以上の人がいると仲良しフィーバータイムに突入だよー！\n仲良しフィーバーは以下の特徴があるよー！\n ・得点が大きくなるよー！\n ⚠投票が被るとその得点を分け合って減点！\n ・ハイリスク、ハイリターンだよー！",nil,"仲良しフィーバータイムだよー！")
    end

    str = ENV["GAME_TIMER"]
    i   = str.to_i - 1
    sleep( i * 60)

  #ゲーム残り１分トゥート！
    exe_toot("・#{h_game["min"]}～#{h_game["max"]}"+GAME_MESSAGE,nil,NOTICE_GAME_SPOILER+fever_txt)

    sleep(60)

  #ゲーム終了トゥート！
    exe_toot(END_GAME_MESSAGE,nil,nil)

  #ゲーム終了ステータスに変更
    File.open(JSON_PATH  + GAME_FILE_PATH,'w') do |io|
      h_game["game_status"] = "DONE"
      JSON.dump(h_game,io)
    end

  #スコア集計するよー！
    #名前ファイルがなかったら作るー！（ここではまだ使わないけど）
    if File.exist?(JSON_PATH  + NAME_FILE_PATH) == false
      File.open(JSON_PATH  + NAME_FILE_PATH,'w') do |io|
        io.puts(JSON.generate({}))
      end
    end

    #投票ファイルを読み込むー！
    h_vote = {}
    if File.exist?(JSON_PATH  + VOTE_FILE_PATH) == false
      File.open(JSON_PATH  + VOTE_FILE_PATH,'w') do |io|
        io.puts(JSON.generate({}))
      end
    else
      h_vote = open(JSON_PATH  + VOTE_FILE_PATH) do |io|
        JSON.load(io)
      end
    end

    h_score = {}
    h_vote.each{|key,value|

      if h_score[value] == nil
        h_score[value] = [key]
      else
        h_score[value].push(key)
      end
    }

    pp h_score  if VERB

    #スコアファイルに書き込むー！
    open( JSON_PATH  + "ZZZ_#{h_game["game_number"]}_" + SCORE_FILE_PATH, 'w') do |io|
      JSON.dump(h_score, io)
    end

  #合計スコアを集計するよー！
    #合計スコアファイルがなかったら作るー！
    if File.exist?(JSON_PATH  + TSCORE_FILE_PATH) == false
      File.open(JSON_PATH  + TSCORE_FILE_PATH,'w') do |io|
        io.puts(JSON.generate({}))
      end
    end

    #合計スコアファイルを読み込むー！
    h_t_score = open(JSON_PATH  + TSCORE_FILE_PATH) do |io|
      JSON.load(io)
    end

    #合計スコアに今回の結果を足し込むよー！
    h_score.each{|key,value|
#      h_t_score[value] = h_t_score[value].to_i + key.to_i

      if value.size == 1   #一人投票の場合
        h_t_score[value[0]] = h_t_score[value[0]].to_i + key.to_i  #獲得した点数を加算
      else

        #フィーバータイムは減算！
        if  h_game["game_mode"] == "HIGH"
          for i in 0..value.size-1 do
            h_t_score[value[i]] = h_t_score[value[i]].to_i - key.to_i  #重複したら減算
            h_t_score[value[i]] = 0  if  h_t_score[value[i]] < 0
          end
        end

        #なかよしタイムは分配！
        if  h_game["game_mode"] == "NKYS"

          d_v = key.to_i.div(value.size)     #商
          m_v = key.to_i.modulo(value.size)  #余り

          if d_v > 0
            for i in 0..value.size-1 do
              h_t_score[value[i]] = h_t_score[value[i]].to_i + d_v  #全員に商分加算
            end
          end

          for i in 0..m_v-1 do
            h_t_score[value[i]] = h_t_score[value[i]].to_i + 1    #余り分を１ずつ分配
          end

        end

        #なかよしフィーバータイムは分配して減算！
        if  h_game["game_mode"] == "NKHI"

          d_v = key.to_i.div(value.size)     #商
          m_v = key.to_i.modulo(value.size)  #余り

          if d_v > 0
            for i in 0..value.size-1 do
              h_t_score[value[i]] = h_t_score[value[i]].to_i - d_v  #全員に商分減算
              h_t_score[value[i]] = 0  if h_t_score[value[i]] < 0
            end
          end

          for i in 0..m_v-1 do
            h_t_score[value[m_v-1-i]] = h_t_score[value[m_v-1-i]].to_i - 1    #余り分を１ずつ減算
            h_t_score[value[m_v-1-i]] = 0   if  h_t_score[value[m_v-1-i]] < 0
          end

        end

      end
    }

    puts "***t_score test**************"  if VERB
    pp h_t_score                          if VERB
    puts "*****************************"  if VERB

    #合計スコアファイルに書き込むー！
    open( JSON_PATH  + TSCORE_FILE_PATH, 'w') do |io|
      JSON.dump(h_t_score, io)
    end

    #順位を設定！
      #安定なソート（多分）
    h_rank = {}
    i = 1
    s = 0
    h_t_score.sort_by{|a,b| [-b, s -= 1] }.each do|k,v|
      puts "#{k} : #{v}" if VERB
      h_rank[k] = i
      i = i + 1
    end

    #順位ファイルに書き込むー！
    open(JSON_PATH  + "ZZZ_#{h_game["game_number"]}_" + RANK_FILE_PATH, 'w') do |io|
      JSON.dump(h_rank, io)
    end

  #ファイルリネームとかコピー！
    File.rename(JSON_PATH  + VOTE_FILE_PATH,   JSON_PATH  + "ZZZ_#{h_game["game_number"]}_" + VOTE_FILE_PATH)
    FileUtils.cp JSON_PATH  + TSCORE_FILE_PATH,  JSON_PATH  + "ZZZ_#{h_game["game_number"]}_" + TSCORE_FILE_PATH

  #分析処理
    analyze()

  #投票結果をトゥートするよー！（自前ではやらず、あっちにお願いするよ！）
    exe_toot("result_fa",ENV["BOT_ID"],nil)

  #スコアをトゥートするよー！（自前ではやらず、あっちにお願いするよ！）
#    exe_toot("score_fa",ENV["BOT_ID"],nil)


  #優勝判定
    s = 0
    v_key = ""
    v_val = 0
    h_t_score.sort_by{|a,b| [-b, s -= 1] }.each do|k,v|
      if  v >= 100
       v_key = k  if v_val < v
       v_val = v  if v_val < v
      end
    end

    #優勝者が出たら・・・！
    if  v_val >= 100

      #名前ファイルを読み込むー！
      h_name = open(JSON_PATH + NAME_FILE_PATH) do |io|
        JSON.load(io)
      end

      #お名前取得ー！
      dispname = ""
      if v_key.match("@") == nil
        dispname = ":@#{v_key}:"
      else
        dispname = ":nicoru:"
      end

      if h_name[v_key] == nil  ||  h_name[v_key] == ""
        dispname += v_key
      else
        dispname += h_name[v_key]
      end

      sleep(5)

      #優勝者は
        exe_toot("#{sprintf("%3d", v_val)}点で #{dispname} が優勝ー！８８８８８８\n⚠スコアは５分後くらいにリセットされるよー！",nil,"【第#{h_game["game_season"]}期】優勝者は……")

      sleep(300)

      #jsonディレクトリリネーム
      File.rename("json",  "json#{sprintf("%02d",h_game["game_season"])}")

      #新しいjsonフォルダを作るー！
      Dir.mkdir(JSON_PATH) unless  Dir.exist?(JSON_PATH)

      #次回の初期ゲームファイル作成してあげるー！
      File.open(JSON_PATH  + GAME_FILE_PATH,'w') do |io|

        #ゲーム情報リセット
        h_game["game_season"] += 1
        h_game["game_number"] = 0
        h_game["game_mode"] = "NKYS"
        h_game["game_status"] = "DONE"
        h_game["min"] = 1
        h_game["max"] = (h_vote.size + 1) / 2 + 5

        #ゲームファイル更新
        JSON.dump(h_game,io)
      end
    end
  end
end


#every(1.hour, 'main', at: '**:31')
#every(1.day, 'main', at: '22:51')
#every(1.day, 'main', at: '23:11')
#every(1.day, 'main', at: '23:51')
#every(1.day, 'main', at: '00:11')
#every(1.day, 'main', at: '21:01')
#every(1.day, 'main', at: '22:01')
#every(1.week, 'main')


every(1.day, 'main', at: '00:31')
every(1.day, 'main', at: '06:31')
every(1.day, 'main', at: '08:31')
every(1.day, 'main', at: '12:31')
every(1.day, 'main', at: '15:01')
every(1.day, 'main', at: '18:31')
every(1.day, 'main', at: '19:31')
every(1.day, 'main', at: '20:31')
every(1.day, 'main', at: '21:31')
every(1.day, 'main', at: '22:31')
every(1.day, 'main', at: '22:51')
every(1.day, 'main', at: '23:31')
every(1.day, 'main', at: '23:51')
#every(1.week, 'main')
