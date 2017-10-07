# coding: utf-8
require 'mastodon'
require 'nokogiri'
require 'json'
require 'highline/import'
require 'oauth2'
require 'dotenv'
require 'pp'


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

MQ_PATH = "mq/"
MQ_FILE_NAME = "mq.json"

ANA_SCORE_PATH = "ana_score.json"
ANA_VOTE_CNT_PATH = "ana_vote_cnt.json"
ANA_VOTE_NUM_PATH = "ana_vote_num.json"
ANA_SCORE_CNT_PATH = "ana_score_cnt.json"


HELP_MESSAGE = "＜help＞\n●投票期間中に指定された範囲内の数字をリプかＤＭでトゥートしてねー！\n●誰とも数字が被らなければ得点になるよー！\n●何回でも投票できるけど、最後の投票が有効だよー！\n●リプで他人に見えるように投票してDMで上書きする作戦もできるよー！\n●用意されているコマンドは以下だよー！\n ・help:このトゥート\n ・score:通算成績\n ・score,xxxx:xxxxさんの通算成績\n ・result:直近の投票結果\n ・myscore:あなたの成績履歴\n ・analyze:統計分析情報\n●以下はネイティオ専用コマンドだよー！\n ・ﾄｩ? :helpと同じ\n ・ﾄｩﾄｩ? :myscoreと同じ\n ・ﾄｩﾄｩﾄｩ? :resultと同じ\n ・ﾄｩﾄｩﾄｩﾄｩ? :scoreと同じ\n  ・ﾄｩﾄｩﾄｩﾄｩﾄｩ? :analyzeと同じ\n ・ﾄｩ! :1\n ・ﾄｩﾄｩ! :2\n …\n ・ﾄｩﾄｩﾄｩﾄｩﾄｩﾄｩ! :6\n …\n"

KIRI_GAME_TAG = "\n #きりゲーム #数取りゲーム"
HELP_SPOILER  = "数取りゲームの説明だよー！"
SCORE_SPOILER = "数取りゲーム成績発表だよー！"

# --- debug switch  true false
VERB = false

############################################################
#トゥートメソッド
def exe_toot(body,acct = nil,spoiler_text = nil,rep_id = nil)
  #おまじないー！
  client = Mastodon::REST::Client.new(base_url: ENV["MASTODON_URL"],
                                      bearer_token: ENV["MASTODON_ACCESS_TOKEN"])
  acct = "@"+acct if acct != nil
  tag = ""
  if  acct == nil
    visibility = "public"
    tag = KIRI_GAME_TAG
  else
    visibility = "direct"
  end
  sleep(1)
  #トゥート！
  client.create_status_kiri( "#{acct} #{body[0,460]}"+tag  , visibility ,spoiler_text,rep_id)
end

############################################################
#お気に入りメソ
def exe_fav(id)
  #おまじないー！
  client = Mastodon::REST::Client.new(base_url: ENV["MASTODON_URL"],
                                      bearer_token: ENV["MASTODON_ACCESS_TOKEN"])
  sleep(1)
  client.favourite(id)
end



############################################################
#スコア取得
def get_score()

  #誰もいません
  return ["まだ誰もいないよー！１"] if File.exist?(JSON_PATH + GAME_FILE_PATH) == false

  #ゲーム情報ファイルを読み込むー！
  h_game = open(JSON_PATH + GAME_FILE_PATH) do |io|
    JSON.load(io)
  end

  #合計スコア・ランクファイルを読み込むー！
  g_num = h_game["game_number"]
  g_sts = h_game["game_status"]

  #今回ファイルを読み込むー！
  g_num = g_num - 1 if g_sts == "EXEC"

  return ["まだ誰もいないよー！２"] if g_num == 0

  h_t_score = open(JSON_PATH + "ZZZ_#{g_num}_" + TSCORE_FILE_PATH) do |io|
    JSON.load(io)
  end

  h_rank = open(JSON_PATH + "ZZZ_#{g_num}_" + RANK_FILE_PATH) do |io|
    JSON.load(io)
  end

  #前回ファイルを読み込むー！
  g_num = g_num - 1

  h_t_score_pre = {}
  h_rank_pre = {}
  if  g_num > 0
    h_t_score_pre = open(JSON_PATH + "ZZZ_#{g_num}_" + TSCORE_FILE_PATH) do |io|
      JSON.load(io)
    end

    h_rank_pre =  open(JSON_PATH + "ZZZ_#{g_num}_" + RANK_FILE_PATH) do |io|
      JSON.load(io)
    end
  end


  #名前ファイルを読み込むー！
  h_name = open(JSON_PATH + NAME_FILE_PATH) do |io|
    JSON.load(io)
  end

  #誰もいません
  return ["まだ誰もいないよー！３"] if h_t_score.size == 0

  #ランキング作成
  text = "\n【第#{h_game["game_season"]}期】第#{g_num+1}回目通算成績\n順位(前回) 得点(前回差) 名前\n"
  a_text = []
  a_text_cnt = 0
  i = 1
  h_rank.each{|k,rank|
    rank_pre_i = h_rank_pre[k].to_i
    score = h_t_score[k]

    diff = h_t_score[k].to_i - h_t_score_pre[k].to_i

    diff_disp = sprintf("%+3d", diff)
    diff_disp = "---" if diff == 0


    rank_pre_s = sprintf("%2d", rank_pre_i)
    if rank_pre_i == 0
      #前回ランクがない場合
      arr = "🆕"
      rank_pre_s = "--"
    else
      m = rank_pre_i - rank
      arr = "↗️" if m >  0
      arr = "➡️" if m == 0
      arr = "↘️" if m <  0
    end

    #お名前取得ー！
    if h_name[k] == nil  ||  h_name[k] == ""
      dispname = k[0,12]
    else
      dispname = h_name[k].to_s[0,7]
    end

    #スコアテキスト１行作るー！

    if k.match("@") == nil
      text += "#{arr}#{sprintf("%2d",rank)}位(#{rank_pre_s}) #{sprintf("%3d", score)}(#{diff_disp}) :@#{k}:#{dispname}\n"          #th
    else                                                                                                                           #th
      text += "#{arr}#{sprintf("%2d",rank)}位(#{rank_pre_s}) #{sprintf("%3d", score)}(#{diff_disp}) :nicoru:#{dispname}\n"         #th
    end                                                                                                                            #th

    #長いのは分割ー！
    if text.size > 400
      a_text[a_text_cnt] = text
      a_text_cnt += 1
      text = "\n【第#{h_game["game_season"]}期】第#{g_num+1}回目通算成績\n順位(前回) 得点(前回差) 名前\n"
    else
      a_text[a_text_cnt] = text
    end
  }

  return a_text

end


############################################################
#結果取得
def get_result()

  #ゲーム情報ファイルを読み込むー！
  h_game = open(JSON_PATH + GAME_FILE_PATH) do |io|
    JSON.load(io)
  end

  #名前ファイルを読み込むー！
  h_name = open(JSON_PATH + NAME_FILE_PATH) do |io|
    JSON.load(io)
  end

  #終了済みの最新スコアファイルを読み込むー！
  g_num = h_game["game_number"].to_i
  g_sts = h_game["game_status"]
  g_num = g_num - 1 if g_sts == "EXEC"

  h_score = open(JSON_PATH + "ZZZ_#{g_num}_" + SCORE_FILE_PATH) do |io|
    JSON.load(io)
  end

  #投票数字降順にソートして名前を列挙！
  h_sort = {}
  h_chk = {}
#  h_score.sort.reverse.each do|k,v|
  h_score.sort_by{|a,b| -a.to_i }.each do|k,v|
    puts "#{k} : #{v}" if VERB

    for i in 0..v.size-1 do

      dispname = ""
      if h_name[v[i]].gsub(/[[:blank:]]/,"") == ""
        dispname = v[i][0,12]
      else
         if v[i].match("@") == nil
           dispname = ":@#{v[i]}:"
         else
           dispname = "#{h_name[v[i]].to_s[0,7]}"
         end
      end

      if  h_sort[k.to_i] == nil
        h_sort[k.to_i] = dispname
      else
        h_sort[k.to_i] = "#{h_sort[k.to_i]} #{dispname}"
      end

    end

    if v.size == 1
      h_chk[k.to_i] = "💮"
    else

      case h_game["game_mode"]
        when "NKYS"
          h_chk[k.to_i] = "💚"
        when "NORM"
          h_chk[k.to_i] = "✖"
        when "HIGH"
          h_chk[k.to_i] = "💀"
      end

    end

  end

  text = "\n【第#{h_game["game_season"]}期】第#{g_num}回 投票結果\n投票数字 投票者名 得点\n"

  h_sort.each{|k,v|

    case h_game["game_mode"]
      when "NKYS"
        if  k.modulo(h_score[ k.to_s ].size) == 0
          text += "#{h_chk[k]}#{sprintf("%2d",k)} :#{v} #{k.div(h_score[ k.to_s ].size)}点\n"
        else
          text += "#{h_chk[k]}#{sprintf("%2d",k)} :#{v} #{k.div(h_score[ k.to_s ].size)+1}～#{k.div(h_score[ k.to_s ].size)}点\n"
        end

      when "NORM"
        if  h_score[ k.to_s ].size == 1
          text += "#{h_chk[k]}#{sprintf("%2d",k)} :#{v} #{k}点\n"
        else
          text += "#{h_chk[k]}#{sprintf("%2d",k)} :#{v} 0点\n"
        end

      when "HIGH"
        if  h_score[ k.to_s ].size == 1
          text += "#{h_chk[k]}#{sprintf("%2d",k)} :#{v} #{k}点\n"
        else
          text += "#{h_chk[k]}#{sprintf("%2d",k)} :#{v} -#{k}点\n"
        end

    end
  }

  return text

end

############################################################
#結果取得old
def get_result_old()

  #ゲーム情報ファイルを読み込むー！
  h_game = open(JSON_PATH + GAME_FILE_PATH) do |io|
    JSON.load(io)
  end

  #名前ファイルを読み込むー！
  h_name = open(JSON_PATH + NAME_FILE_PATH) do |io|
    JSON.load(io)
  end

  #終了済みの最新投票ファイルを読み込むー！
  g_num = h_game["game_number"].to_i
  g_sts = h_game["game_status"]
  g_num = g_num - 1 if g_sts == "EXEC"

  h_t_vote = open(JSON_PATH + "ZZZ_#{g_num}_" + VOTE_FILE_PATH) do |io|
    JSON.load(io)
  end

  #投票数字降順にソートして名前を列挙！
  h_sort = {}
  h_chk = {}
  h_t_vote.sort{|a, b| b[1] <=> a[1]}.each do|k,v|
    puts "#{k} : #{v}" if VERB

    if h_name[k] == nil  ||  h_name[k] == ""
      dispname = k[0,12]
    else
#      dispname = ":@#{k}:#{h_name[k].to_s[0,7]}"
#      dispname = "#{h_name[k].to_s[0,7]}"
       if k.match("@") == nil
         dispname = ":@#{k}:"
       else
         dispname = "#{h_name[k].to_s[0,7]}"
       end
    end

    if  h_sort[v] == nil
      h_sort[v] = dispname
      h_chk[v] = "💮"
    else
      h_sort[v] = "#{h_sort[v]} #{dispname}"
      h_chk[v]  = "✖️"
    end
  end

  text = "\n【第#{h_game["game_season"]}期】第#{g_num}回 投票結果\n投票数字 投票者名\n"

  h_sort.each{|k,v|
    text += "#{h_chk[k]}#{sprintf("%2d",k)} :#{v}\n"
  }

  return text

end


############################################################
#結果取得
def get_myscore(acct)

  #ゲーム情報ファイルを読み込むー！
  h_game = open(JSON_PATH + GAME_FILE_PATH) do |io|
    JSON.load(io)
  end

  #名前ファイルを読み込んで、名前を取得ー！
  h_name = open(JSON_PATH + NAME_FILE_PATH) do |io|
    JSON.load(io)
  end

  my_disp_name = h_name[acct]
  my_disp_name = acct if my_disp_name == nil  ||  my_disp_name == ""

  text = "\n【第#{h_game["game_season"]}期】:@#{acct}:#{my_disp_name}さんの履歴\n"  #th
  text += "回数 順位 スコア\n"

  #順次、スコア、ランキングファイルを読み込み
  g_num = h_game["game_number"].to_i
  g_sts = h_game["game_status"]
  g_num = g_num - 1 if g_sts == "EXEC"


  a_text = []
  a_text_cnt = 0
  for i in 1..g_num do

    j = g_num + 1 - i

    h_rank = open(JSON_PATH + "ZZZ_#{j}_" + RANK_FILE_PATH) do |io|
      JSON.load(io)
    end

    h_score = open(JSON_PATH + "ZZZ_#{j}_" + TSCORE_FILE_PATH) do |io|
      JSON.load(io)
    end

    text += "第#{sprintf("%2d",j)}回 #{sprintf("%2d",h_rank[acct])}位 #{sprintf("%3d",h_score[acct])}点\n" if h_score[acct] != nil

    #長いのは分割ー！
    if text.size > 400
      a_text[a_text_cnt] = text
      a_text_cnt += 1
      text = "\n【第#{h_game["game_season"]}期】#{my_disp_name}さんの履歴\n"
      text += "回数 順位 スコア\n"
    else
      a_text[a_text_cnt] = text
    end

  end


  return a_text

end

############################################################
# ネイティオコマンド変換
def twotwo(text)
  twotwo_text = text

  #末尾１文字を判定！
  case text[-1]
    #コマンドの場合！
    when "?"
      case text
        when "ﾄｩ?"
          twotwo_text = "help"
        when "ﾄｩﾄｩ?"
          twotwo_text = "myscore"
        when "ﾄｩﾄｩﾄｩ?"
          twotwo_text = "result"
        when "ﾄｩﾄｩﾄｩﾄｩ?"
          twotwo_text = "score"
        when "ﾄｩﾄｩﾄｩﾄｩﾄｩ?"
          twotwo_text = "analyze"
      end
    #数値投票の場合！
    when "!"
      twotwo_text = text.gsub(/T/,"X").gsub(/ﾄｩ/,"T").count("T").to_s
  end

  puts "ネイティオ変換：#{twotwo_text}"  if VERB
  return twotwo_text

end


############################################################
#あいさつなどの返答文言作成
def response(text,id = nil)

   #ＩＤ別
   return "(╯°□°）╯︵ ┻━┻＜ﾋﾟﾀｯ!" if id == "under_the_desk"
   return "₍₍◝( ◠‿◠)◟⁾⁾ﾎﾋﾎﾋﾀﾞﾝｽｰ!" if id == "hiho_karuta"
   return "₍₍◝( ◠‿◠)◟⁾⁾ﾊﾛﾊﾛﾀﾞﾝｽｰ!" if id == "abcdefghijklmn"
   return "₍₍◝( ◠‿◠)◟⁾⁾ｺﾞﾐｺﾞﾐﾀﾞﾝｽｰ!" if id == "gomi_ningen"

   #メッセージ別
   return "@kiritan メッセージを転送するよー！「#{text[0,400]}」" if text.match(/き.?り.?た[んー]|きりきり|きりぽ/) !=nil
   return "@JC ももなにメッセージだよー！「#{text[0,400]}」" if text.match(/ももな/) !=nil
   return "₍₍⁽⁽(ી( ･◡･ )ʃ)₎₎⁾⁾＜おはおはダンス第２ー！" if text.match(/おはよ|おあひょ/) !=nil
   return "おめありー！" if text.match(/おめで[とた][うい]/) !=nil                    #th
   return "@kiritan 下ネタはきりたんに通報しまーす！「#{text[0,400]}」" if text.match(/ちん[ちこぽ]|まんこ|うん[こち]|おまんちん|ﾁﾝｺ|ﾏﾝｺ|ㄘんㄘん|ﾘﾌﾞﾘﾌﾞ|膣|おっぱい|早漏/) !=nil
   return "おやすみー！" if text.match(/[寝ね](ます|る|マス)|(.*)[ぽお]や[すし]み/) !=nil
   return "( *ˊᵕˋ)ﾉˊᵕˋ*) ﾅﾃﾞﾅﾃﾞ" if text.match(/なでなで|ﾅﾃﾞﾅﾃﾞ|ガ[ー～]ン|が[ー～]ん/) !=nil
   return "ぼっとなので疲れないよー！" if text.match(/おつかれ/) !=nil
   return "北ニア国物語" if text.match(/prpr|ぺろぺろ|ペロペロ|ちゅっ/) !=nil
   return "乳酸菌取ってるよー！" if text.match(/乳酸菌.*？/) !=nil
   return "おっすー！" if text.match(/おっす|おいっす/) !=nil
   return "やっほー！" if text.match(/こん..わ|やっほ|はろー/) !=nil
   return "えへへ！" if text.match(/かわい[いー]/) !=nil
   return "よかったなー！\n( *ˊᵕˋ)ﾉˊᵕˋ*) ﾅﾃﾞﾅﾃﾞ" if text.match(/や.?った[よぜ]/) !=nil
   return "チャオ(◍•ᴗ•◍)ﾉﾞ" if text.match(/ちゃお|チャオ/) !=nil
   return "っ💴" if text.match(/5000兆円/) !=nil
   return "ｷﾘｯ" if text.match(/ぬるぽ|ﾇﾙﾎﾟ|null.point/) !=nil
   return "だれいま！" if text.match(/ちくわ大明神/) !=nil
   return "ん？" if text.match(/なんでも|何でも/) !=nil
   return "はーい！" if text.match(/人工知能|[Bb][Oo][Tt]/) !=nil
   return "あけおめー！" if text.match(/あけ.*おめ.*/) !=nil
   return "わーい！てれほー！" if text.match(/てれほ/) !=nil
   return "・・・お断りしまーす！" if text.match(/結婚しよ/) !=nil
   return "っ🍙どうぞー！" if text.match(/腹.*減った|腹.*いた/) !=nil
   return "めうめうめう！" if text.match(/めう/) !=nil
   return "どういたしましてー！" if text.match(/ありがと|サンクス|さんくす|thx|thanks/) !=nil
   return "なあにー？" if text.match("きりぼっと") !=nil
   return "すこすこのスコティッシュフォールド！" if text.match(/スコティッシュフォールド/) !=nil
   return "ﾍﾟﾁｯﾍﾟﾁｯなのだわ！" if text.match(/ﾍﾟﾁｯ/) !=nil
   return "@5 転送しまーす！「#{text[0,400]}」" if text.match(/[やヤ][なナ][るル]|[イい][キき][リり]/) !=nil
   return "@tudiiku 転送しまーす！「#{text[0,400]}」" if text.match(/まないた|つぢ[いー]|まな板/) !=nil
   return "@sink_lincale 転送しまーす！「#{text[0,400]}」" if text.match(/🔪|包丁/) !=nil
   return "@USG 転送しまーす！「#{text[0,400]}」" if text.match(/まぐろ|マグロ/) !=nil
   return "@hihobot1 転送しまーす！「#{text[0,400]}」" if text.match(/\s?(.+)って(何|なに|ナニ)？$/) !=nil
   return "@hihobot1 わかんないんだー！" if text.match(/なんすか$/) !=nil
   return "@mei23 めいめいに転送しまーす！「#{text}」" if text.match(/なのだわ/) !=nil
   return "@12 ひょろわ～に転送しまーす！「#{text}」" if text.match(/ひょろわ|ひょろお[じぢ]|🍡/) !=nil
   return "@shiroma しろまさんに転送しまーす！「#{text}」"  if text.match(/にぇ〜|ゆぉ〜/) !=nil
   return "あうあうあー"   if text.match(/＾p＾|^p^/) !=nil
   return "わかったー！（わかってない）"   if text.match(/そこをなんとか|そこを何とか/) !=nil
   return "お風呂入ってくるー！覗かないでねー！"   if text.match(/お風呂.*入/) !=nil


   return "いいえ！" if text.match(/質問|LINE|？/) !=nil


   return nil
end


############################################################
#標準化処理
def normalize(text)

  #全角文字は半角へ、大文字は小文字へ！
  n_text = text.tr('０-９ａ-ｚＡ-Ｚ', '0-9a-zA-Z').downcase

  #余計なブランク類は削除
  n_text.gsub!(/[[:blank:]]/,"")

  return n_text if n_text == ""

  #解析
  if n_text[0,1].match(/[0-9]/) != nil
  #先頭が数値なら数値とみなしてー！
    md = n_text.match(/[0-9]+/)
    return md[0]
  else
  #文字ならコマンドかな？
    return "score,12" if text.match(/ぅゅ.*(成績|スコア|ｽｺｱ|点数)/) !=nil

    return "help" if text.match(/help|使い方|コマンド|助け|どんな.*機能.*？/) !=nil
    return "myscore" if text.match(/myscore|(私|わたし|わたくし|自分|僕|俺|朕|ちん|余|あたし|ミー|あちき|あちし|わい|わっち|おいどん|わし|うち|おら|儂|おいら|あだす|某|麿|拙者|小生|あっし|手前|吾輩|我輩|マイ).*(成績|スコア|ｽｺｱ|点数)/) !=nil
    return "score" if text.match(/成績|スコア|ｽｺｱ|点数|すこあ/) !=nil
    return "result" if text.match(/result|投票結果|今回.*結果/) !=nil
    return "analyze" if text.match(/analyze|分析|統計/) !=nil
    return "0" if text.match(/null/) !=nil

  end

  return n_text

end

############################################################
#投票処理
def exe_vote(votenum,acct,name)
  #投票ファイルがなかったら作るー！
  if File.exist?(JSON_PATH + VOTE_FILE_PATH) == false
    File.open(JSON_PATH + VOTE_FILE_PATH,'w') do |io|
      io.puts(JSON.generate({}))
    end
  end

  #投票ファイルを読み込むー！
  h_vote = open(JSON_PATH + VOTE_FILE_PATH) do |io|
    JSON.load(io)
  end

  h_vote[acct] = votenum

  p h_vote if VERB

  #投票ファイルに書き込むー！
  open(JSON_PATH + VOTE_FILE_PATH, 'w') do |io|
    JSON.dump(h_vote, io)
  end

  #名前ファイルがなかったら作るー！
  if File.exist?(JSON_PATH + NAME_FILE_PATH) == false
    File.open(JSON_PATH + NAME_FILE_PATH,'w') do |io|
      io.puts(JSON.generate({}))
    end
  end

  #名前ファイルを読み込むー！
  h_name = open(JSON_PATH + NAME_FILE_PATH) do |io|
    JSON.load(io)
  end

  #名前を格納、更新！
  h_name[acct] = name.gsub(/:[^:]+:/,"")    #th
  h_name[acct] = acct  if name.gsub(/[[:blank:]]/,"") == ""  #th


  #5の人の名前は固定にするー！
  h_name[acct] = "イキリオタク"  if acct == "5"

  p h_name if VERB

  #名前ファイルに書き込むー！
  open(JSON_PATH + NAME_FILE_PATH, 'w') do |io|
    JSON.dump(h_name, io)
  end
end


#####################################################
# 分析結果
def get_analyze()

  h_score = {}        #総得点
  h_vote_cnt = {}   #投票回数
  h_vote_num = {}     #投票人数
  h_score_cnt = {}  #得点回数

  if File.exist?(JSON_PATH  + ANA_SCORE_PATH) == false
    return ["分析結果がまだないよー！"]
  else
    h_score = open(JSON_PATH  + ANA_SCORE_PATH) do |io|
      JSON.load(io)
    end

    h_vote_cnt = open(JSON_PATH  + ANA_VOTE_CNT_PATH) do |io|
      JSON.load(io)
    end

    h_vote_num = open(JSON_PATH  + ANA_VOTE_NUM_PATH) do |io|
      JSON.load(io)
    end

    h_score_cnt = open(JSON_PATH  + ANA_SCORE_CNT_PATH) do |io|
      JSON.load(io)
    end
  end

  #ヘッダ
  text = "\n分析結果\n値 期待値 獲得率 獲得数 投票数 人数\n"

  #レコード
  a_text = []
  a_text_cnt = 0

  h_score.sort_by{|k,v|k.to_i}.each{|key,value|

    exp_val = 0.0
    exp_val = value.to_f/h_vote_cnt[key].to_f if  h_vote_cnt[key].to_i != 0
    rate    = 0.0
    rate    = h_score_cnt[key].to_f*100/h_vote_cnt[key].to_f if  h_vote_cnt[key].to_i != 0

    text += "#{sprintf("%2d",key)} #{sprintf("%5.2f", exp_val )} #{sprintf("%5.1f", rate) }％ #{sprintf("%4d",h_score_cnt[key])}回 #{sprintf("%4d",h_vote_cnt[key])}回 #{sprintf("%3d",h_vote_num[key])}人\n"

    #長いのは分割ー！
    if text.size > 400
      a_text[a_text_cnt] = text
      a_text_cnt += 1
      text = "\n分析結果\n値 期待値 獲得率 獲得数 投票数 人数\n"
    else
      a_text[a_text_cnt] = text
    end
  }


  return a_text

end


############################################################
#メイン処理

puts "処理開始ー！"

while true do

  puts "ループ中"  if VERB

  Dir.glob("#{MQ_PATH}*#{MQ_FILE_NAME}").sort.each{|file_path|

   begin


    puts "####ファイル処理中ー！############"
    pp file_path

    msg_data = {}
    File.open(file_path, "r") do |f|
      msg_data = f.read
    end
#    msg_data = open(file_path) do |io|
#      JSON.load(io)
#    end

    pp msg_data  if VERB
    toot = JSON.parse(msg_data)

    case toot["event"]
      when "notification"

        body = JSON.parse(toot["payload"])

        p body["type"] if VERB
        #タイプ別処理！
        case body["type"]
          when "mention"

            contents = Nokogiri::HTML.parse(body["status"]["content"])

            exe_fav(body["status"]["id"])
            text = ''

            contents.search('p').children.each do |item|
              text += item.text.strip if item.text?
            end

            #標準化処理
            text = normalize(text)

            #ネイティオ専用 変換処理
            if body["account"]["acct"] == "twotwo" || body["account"]["acct"] == "kiritan"
#                if body["account"]["acct"] == "kiritan"
              text = twotwo(text)
            end

            #ゲーム情報ファイルを読み込むー！
            h_game = {}
            if File.exist?(JSON_PATH + GAME_FILE_PATH) != false
              h_game = open(JSON_PATH + GAME_FILE_PATH) do |io|
                JSON.load(io)
              end
            end

            #数値が投票されたらー！
            i = text[0,4].to_i
            puts i, text  if VERB
#            if i != 0
            if text =~ /^[0-9]+$/    #数字判定 改定

              #投票期間中のみ！
              if  h_game["game_status"] == "EXEC"

                puts h_game["min"],h_game["max"] if VERB
                j = h_game["min"]
                k = h_game["max"]

                #範囲内のみ！
                if  ((j <= i) && (i <= k )) || i == 0

                  exe_vote(i,body["account"]["acct"],body["account"]["display_name"])

#                  exe_toot("#{i}に投票したよ！",body["account"]["acct"],nil,body["status"]["id"])

                else
                  exe_toot("数値が範囲外だよー！",body["account"]["acct"],nil,body["status"]["id"])
                end

              else
                exe_toot("投票は締め切ったので、次回を待ってねー！",body["account"]["acct"],nil,body["status"]["id"])
              end

            #数値以外なら、問い合わせかなー！
            else
              case  text

                when  "help_fa"
                  if body["account"]["acct"] == "kiritan"
                    exe_toot(HELP_MESSAGE,nil , HELP_SPOILER,body["status"]["id"])
                  else
                    exe_toot("権限がないよー！",body["account"]["acct"],nil,body["status"]["id"])
                  end

                when  "help"
                  exe_toot(HELP_MESSAGE,body["account"]["acct"],nil,body["status"]["id"])

                when  "score_fa"
                  if body["account"]["acct"] == "kiritan"
                    score = get_score()
                    for i in 0..score.size-1 do
                      exe_toot(score[i],nil, SCORE_SPOILER+"<#{i+1}/#{score.size}>",body["status"]["id"])
                    end
                  else
                    exe_toot("権限がないよー！",body["account"]["acct"],nil,body["status"]["id"])
                  end

                when  "score"
                  score = get_score()
                  for i in 0..score.size-1 do
                    exe_toot(score[i],body["account"]["acct"],SCORE_SPOILER+"<#{i+1}/#{score.size}>",body["status"]["id"])
                  end

                when  "myscore"
                  myscore = get_myscore(body["account"]["acct"])
                    for i in 0..myscore.size-1 do
                      exe_toot(myscore[i],body["account"]["acct"], "数取りゲームの個人成績だよー！<#{i+1}/#{myscore.size}>",body["status"]["id"])
                    end

                when  "result"
                  result = get_result()
                  exe_toot(result,body["account"]["acct"],"今回の結果だよー！",body["status"]["id"])

                when  "result_fa"
                  if body["account"]["acct"] == "kiritan"
                    result = get_result()
                    exe_toot(result,nil, "今回の結果だよー！",body["status"]["id"])
                  else
                    exe_toot("権限がないよー！",body["account"]["acct"],nil,body["status"]["id"])
                  end

                when  "analyze"
                  result = get_analyze()
                    for i in 0..result.size-1 do
                      exe_toot(result[i],body["account"]["acct"], "分析結果だよー！<#{i+1}/#{result.size}>",body["status"]["id"])
                    end

                else
                  a_text = text.split(",")
                  case a_text[0]
                    when  "score"
                      myscore = get_myscore(a_text[1])
                      for i in 0..myscore.size-1 do
                        exe_toot(myscore[i],body["account"]["acct"], "数取りゲームの個人成績だよー！<#{i+1}/#{myscore.size}>",body["status"]["id"])
                      end

                    else
                      #あいさつなどを返す
                      res  =  response(text,body["account"]["acct"])
                      if  res == nil
                        exe_toot("何言ってるかわかんなーい！٩(๑`^´๑)۶「#{text}」 @kiritan",body["account"]["acct"],nil,body["status"]["id"])
                      else
                        exe_toot(res,body["account"]["acct"],nil,body["status"]["id"])
                      end
                  end

              end

            end

          #今は使わないー！
          when "favourite"
          when "reblog"

        end

      when  "update"
        body = JSON.parse(toot["payload"])
        contents = Nokogiri::HTML.parse(body["content"])

        exe_fav(body["id"])
        text = ''

        contents.search('p').children.each do |item|
          text += item.text.strip if item.text?
        end

        case  text
          when  "help_fa"
            exe_toot(HELP_MESSAGE,nil , HELP_SPOILER)
          when  "score_fa"
            score = get_score()
            for i in 0..score.size-1 do
              exe_toot(score[i]+"\n       <#{i+1}/#{score.size}>\n",nil, SCORE_SPOILER)
            end
          when  "result_fa"
            result = get_result()
            exe_toot(result,nil, "今回の結果だよー！")
        end



      #今は使わないー！
      when "delete"

    end

    rescue => e
      puts "error 0020"
      puts e
    end


    #処理したファイルは消す（移動）
#    Dir.mkdir("del/") unless  Dir.exist?("del/")
#    Dir.mkdir("del/"+JSON_PATH) unless  Dir.exist?("del/"+JSON_PATH)
#    Dir.mkdir("del/"+JSON_PATH+MQ_PATH) unless  Dir.exist?("del/"+JSON_PATH+MQ_PATH)
#    File.rename(file_path,"del/"+file_path)
    File.delete(file_path)


  }

  sleep(1)

end
