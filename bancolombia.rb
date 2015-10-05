require 'mechanize'
require 'highline/import'
require 'pry'

class Bancolombia
  attr_accessor :agent, :username, :password

  def initialize
    @agent = Mechanize.new
    @encrypted_password = ''
  end

  def balance
    begin
      store_credentials
      create_bank_session
      login_username
      login_password
      check_authentication
    rescue Exception => e
      puts e.message
    end
  end

private
  def check_authentication
    authentication_page = @agent.get('https://bancolombia.olb.todo1.com/olb/Authentication')
    if invalid_authentication(authentication_page)
      raise 'Invalid username or password, please try again'
    end
    if authentication_page.search('td.err_validation').text.strip.match('equipo no registrado')
      answer_secret_questions(authentication_page)
    end
  end

  def answer_secret_questions(questions_page)
    puts 'This devise is not registered, you must answer the secret questions'
    answer1 = ask questions_page.search('#luserAnswer1').text.strip
    answer2 = ask questions_page.search('#luserAnswer2').text.strip
    page = questions_page.form_with(:name => "checkChallQuestForm") do |f|
      f.userAnswer1 = answer1
      f.userAnswer2 = answer2
      f.radiobuttons.first.check
    end.click_button
    binding.pry
    r = 1
  end

  def invalid_authentication(page_html)
    page_html.search('td.err_validation table tr td').text.strip.match('intente de nuevo') ||
    page_html.search('table.errorMsg').text.strip.match('CODIGO:BC BBP10014')
  end

  def create_bank_session
    @agent.get('https://bancolombia.olb.todo1.com/olb/Init')
  end

  def get_encrypted_password(page_html)
    encrypted_password = ''
    ##Insert \r for correct regex on password scripts
    page_html.gsub!(/document.getElementById/, "\r\n\t document.getElementById")
    @password.to_s.split('').each do |n|
      page_html.match(/\'td_#{n}\'\)\.addEventListener\(\'click\'\,\sfunction\(\)\{\S*\(\"(.*)\"\)\;\}/);
      encrypted_password << $1
    end
    encrypted_password
  end

  def hidden_field_name_in_login_password(page_html)
    page_html.match(/'PASSWORD\':\'(.*)\'/)[1]
  end

  def login_username
    log_in_username = @agent.get('https://bancolombia.olb.todo1.com/olb/Login')
    log_in_username.form_with(:name => 'authenticationForm') do |f|
      f.userId = username
    end.click_button
  end

  def login_password
    password_page = @agent.get('https://bancolombia.olb.todo1.com/olb/GetUserProfile')
    encrypted_password = get_encrypted_password(password_page.body)
    secret_hidden_field = hidden_field_name_in_login_password(password_page.body)
    password_page.form_with(:name => "authenticationForm") do |f|
      f.userId = '0'
      f.password = encrypted_password
      f.add_field!(secret_hidden_field, value = encrypted_password)
    end.click_button
  end

  def store_credentials
    @username = ask('Enter username: ')
    @password = ask('Enter 4 digits password: ') { |q| q.echo = "*" }
  end
end

bancolombia = Bancolombia.new
bancolombia.balance


# @agent.get("https://bancolombia.olb.todo1.com/olb/Authentication")
# balancePage = agent.get("/olb/BeginInitializeActionFromCM?from=pageTabs")
# balance = balancePage.search(".contentTotalNegrita").last.children.text
# puts "Your actual balance is: $#{balance}"
