require 'mastodon'
require 'openai'
require 'dotenv'
require 'logger'

# 環境変数の読み込み
Dotenv.load

# ロガーの生成
logger = Logger.new(STDERR)

# 投稿のトリミング処理
def trim_content(content)
  content.gsub(/<p>|<\/p>|<span>|<\/span>|<span class="h-card"><a href="#{ENV['MASTODON_URL']}\/@Creatodon" class="u-url mention" rel="nofollow noopener noreferrer" target="_blank">|<span class="h-card"><a href="#{ENV['MASTODON_URL']}\/@Creatodon" class="u-url mention">/, '')
    .sub(/@Creatodon<\/a>/, '')
    .gsub(/<br \/>/, '')
    .gsub(/<br>/, '')
end

loop do
  begin
    # クライアントを初期化
    mastodon_client = Mastodon::REST::Client.new(base_url: ENV['MASTODON_URL'], bearer_token: ENV['ACCESS_TOKEN'])

    mastodon_client.notifications.each do |notification|
      # メンション以外の場合はスキップ
      next if notification.type != 'mention'


      # メンションのStatusを取得
      status = notification.status

      # サーバー内のユーザー以外からのメンションはスキップ
      next if status.account.acct.include?('@')

      # メンションの公海範囲を取得
      visibility = status.visibility

      # メンションで受け取った内容を正規表現でTrim
      content = trim_content(status.content)

      openai_client = OpenAI::Client.new(access_token: ENV['OPEN_AI_TOKEN'])

      response = openai_client.chat(
        parameters: {
          model: "gpt-3.5-turbo", # GPT-3.5を利用
          messages: [{ role: "user", content: content}], # メンションで受け取った内容を送信
          temperature: 0.7,
      })

      response_content = response.dig("choices", 0, "message", "content")

      # メンションに返信
      mastodon_client.create_status("@#{status.account.acct}\n#{response_content}", {in_reply_to_id: status.id, visibility: status.visibility})

      # 通知の削除
      mastodon_client.clear_notifications

      # 遅延処理
      sleep(30)
    end
  rescue => e
    logger.error("Error!")
    logger.error(e.full_message)
  end
end