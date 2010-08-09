require 'rubygems'
require 'json'
require 'rest_client'
require 'isaac'
require 'cgi'

configure do |c|
  c.nick    = "YelpBot"
  c.server  = "irc.freenode.net"
end

on :connect do
  join "#rmu-session-0 zerowing"

end

on :channel, /^!yelp (.*)/ do
  #msg channel, "yelp results: #{match[0]}"
  unless match[0] == "-h"
    yelp match[0]
  else
    yelpBot_help
  end
end


helpers do 
  def yelp(match_results)
    
    # get rid of commas from my params
    params = match_results.split(",").join(" ")
    params = params.split(" ")
    # Need error processing here, and usage guidlines
    
    # ready params for the query
    biz = params.shift
    location = params.join(" ")
    
    # create yelp query object and send request
    @yelp_query = YelpQuery.get do |y|
      y.term = biz
      y.location = location
    end
    
    # output into irc
    msg channel, "#{@yelp_query.to_irc}"
  end
  
  def yelpBot_help
    msg channel, "usage: !yelp [search term (e.g. 'bars' for multiple words use '+' instead of ' ')] [location (e.g. 'Portland, OR')]"
  end
end

######################################################################################################
# Yelp interaction
######################################################################################################

class YelpQuery
  attr_accessor :term, :location, :category, :query, :results, :refined_results, :output, :message
  
  YELP_URI = "http://api.yelp.com/business_review_search?"
  
  ####################################################################################################
  # yelp api key goes here, they made me promise not to share mine :(
  #
  YWSID = "" 
  #
  #
  ######################################################################################################
  
  def self.get(*args, &block)
    yelp = YelpQuery.new
    yelp.instance_eval(&block)
    yelp.get
    yelp
  end
  
  def get
    # make query and url encode
    @query = String.new
    @query << YELP_URI
    
    query = Array.new
    query << "term=#{@term}"
    query << "location=#{CGI::escape(@location)}"
    query << "ywsid=#{YWSID}"
    query << "category=#{category}" unless @category == nil
    
    @query << query.join("&")
    
    # send get request via restclient and capture results in instance variable
    resource = RestClient::Resource.new(@query)
    @results = JSON.parse(resource.get)

    # Handle bad requests
    # TODO error handling
    @message = @results["message"]
  end
  
  def process_output(limit=3)
    # process results to be sent to be put in irc
    @refined_results = Array.new
    @results["businesses"].each do |b|
      h = Hash.new
      h["name"]        = b["name"]
      h["url"]  = b["url"]
      h["avg_rating"]  = b["avg_rating"]
      
      # constrain the number of businesses shown
      unless @refined_results.length >= limit
        @refined_results << h
      else
        break
      end
    end
    
    # convert the refined results to final format for to be put into the irc room
    @output = Array.new
    @refined_results.each do |rr|
      @output << "#{rr["name"]}, #{rr["mobile_url"]}, rated: #{rr["avg_rating"]}"
    end
    @output = @output.join(" | ")
  end
  
  def handle_response_codes
    @output = case @message["code"]
    when 0
      process_output
    else
      "Could not complete request: #{@message["text"]}"
    end
  end
  
  def to_irc
    handle_response_codes
  end
  
end