# frozen_string_literal: true

require "sinatra/base"

module MFYNAB
  class FakeMoneyforwardApp < Sinatra::Base
    set :logging, false

    get "/sign_in" do
      <<~HTML
        <form action="/sign_in/email" method="post">
          <input required="" type="email" name="mfid_user[email]">
          <div style="height: 0; width: 0; overflow: hidden;">
            <input type="password" name="mfid_user[password]">
          </div>
          <button id="submitto">Sign in</button>
        </form>
      HTML
    end

    post "/sign_in/email" do
      if params["mfid_user"]["email"] == "david@example.com" && params["mfid_user"]["password"] == "Passw0rd!"
        response.set_cookie("_moneybook_session", value: "dummy_session_id", path: "/")
        redirect "/"
      else
        "Invalid email or password"
      end
    end

    get "/" do
      #require "debug"; debugger
      if request.cookies["_moneybook_session"] == "dummy_session_id"
        "Logged in"
      else
        "Not logged in"
      end
    end

    # TODO: logout
  end
end
