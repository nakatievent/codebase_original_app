require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/cookies'
require 'pry'
require "fileutils"
require 'pg'

enable :sessions

client = PG::connect(
  :host => "localhost",
  :user => ENV.fetch("USER", "codebase"), :password => 'pass',
  :dbname => "myapp")

# トップページ
get "/top_page" do
  @top_page = "一問Webアプリケーション"
  erb :top_page
end

# 新規登録
get '/signup' do
  @app_name = "一問Webアプリケーション"
  erb :signup
end

# 新規登録ポスト
post '/signup' do
  name = params[:name]
  email = params[:email]
  password = params[:password]
  # データの挿入↓
  client.exec_params("INSERT INTO users (name, email, password) VALUES ($1, $2, $3)", [name, email, password])
  user = client.exec_params("SELECT * from users WHERE email =$1 AND password = $2", [email, password]).to_a.first
  session[:user] = user
  redirect '/mypage'
end

# ログインページ
get "/login" do
  @app_name = "一問一答Webアプリケーション"
  erb :login
end

# ログインポスト
post "/login" do
  email = params[:email]
  password = params[:password]
  user = client.exec_params("SELECT * FROM users WHERE email ='#{email}' AND password = '#{password}'").to_a.first
  if user.nil?
    return erb :login
  else
    session[:user] = user
    redirect '/mypage'
  end
end

# ログアウト
delete '/signout' do
  session[:user] = nil
  redirect '/login'
end

# マイページ
get "/mypage" do
  @name = session[:user]['name']
  @img = client.exec_params("SELECT content FROM picture WHERE user_id = $1 order by id desc", [session[:user]["id"]]).to_a.first
  erb :mypage
end

# マイページポスト
post "/mypage" do
  @name = session[:user]['name'] # 書き換える
  if !params[:img].nil? # データがあれば処理を続行する
    tempfile = params[:img][:tempfile] # ファイルがアップロードされた場所
    save_to = "./public/image/#{params[:img][:filename]}" #ファイルを保存したい場所
    FileUtils.mv(tempfile, save_to)
    img = params[:img][:filename]
    # データの挿入↓
    client.exec_params("INSERT INTO picture (user_id, content) VALUES ($1, $2)", [session[:user]["id"], img])
  end
    redirect '/mypage'
end

# 問題ページ
get "/question/:page" do
  @question_id = params[:page].to_i
  @question = client.exec_params("select question from q_and_a2 where id = '#{@question_id}'").first["question"]
  erb :question
end


# 質問の回答をポストに送る＆答えを表示するページ
post "/answer/:page" do
  @question_id = params[:page].to_i
  @ans = params[:answer]
  @answer = client.exec_params("select answer from q_and_a2 where id = '#{@question_id}'").first["answer"]
  @explanation = client.exec_params("select explanation from q_and_a2 where id = '#{@question_id}'").first["explanation"]

  # score変数を用意し、最初はまだ問題に答えていないので０点を代入する。
  if @question_id == 1
    session[:user]['score'] = 0
  end
  score = 0

  # もし、自分の答えが正解であれば、スコアを１点追加する。
  if @ans == @answer
    score += 1
  end

  # session[:user] にハッシュで{score=>"score"}を代入する。＠scoreにsession[:user]['score']を代入することで点数を表示することができる。
  session[:user]['score'] += score
  @score = session[:user]['score'] 
  erb :answer
end


get '/result' do
  @total_score = session[:user]['score'] 
  erb :result
end