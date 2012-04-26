  # Controlers

  ## How can I handle HTTP verbs (GET, POST, ..) separately ?

You can inspect request.env['REQUEST_METHOD']. Here is an example that calls different methods depending on HTTP method used :

    class Servant < Ramaze::Controller
      def index(method, *args)
         real_method = request.env['REQUEST_METHOD'].downcase
         real_method << "_"  + method.downcase
         send(real_method, args) if self.class.method_defined?(real_method)
      end

      def get_me(*args)
        "<h1>Here is #{args.join ' '}</h1><br/>"
      end

      def post_me(*args)
        "<h1>sorry, can't post you #{args.join ' '}. Postoffice is closed."
      end
    end

This will be used like this :

    $ curl http://localhost:7000/v1/mailbox/me/a/drink
    Here is a drink
    $ curl -d "" http://localhost:7000/v1/mailbox/me/a/letter
    Sorry, can't post you a letter. Postoffice is closed.


# Layout and Views

## I want to add a dynamic sidebar in my layout

How can I render multiple things in my layout (not just @content) ?

There are many ways to do that. You can use a  helper for instance :

    module Ramaze
      module Helper
        module SideBar

          def generate(current=nil)
            # Generate somt HTML that will make the side bar

            sidebar = "<div class="sd"><h1>This is a sidebar</h1>"
            sidebar<< "<ul>"
            sidebar<< "<li>First item</li>"
            sidebar<< "<li>Second item</li>"
            sidebar<< "</ul></div>"

            sidebar.to_s
          end

        end
      end
    end

To activate your helper, you have to set it in at least one controller :

    class Controller < Ramaze::Controller
      layout :default
      helper :sidebar
      ....

This way, Ramaze will take care of loading your helper class automatically.
Then, in your layout, you just have to call you Sidebar#generate method :

    <div class="sidebar-nav">
      #{generate}
    </div>

## How can I write HTML programatically

Just use {Ramaze::Gestalt}. It's a utility class that can help you writing html programatically, so you dan't have to "stuff" a String with HTML, or use _here_ documents.

Here is the above code, revisited with Ramaze:Gestalt

    def generate(current=nil)
      # Generate some HTML that will make the side bar

      sidebar = Ramaze::Gestalt.new

      sidebar.div(:class =>"sd") do
        sidebar.h1 "This is a sidebar"
        sidebar.ul do
          sidebar.li "First item"
          sidebar.li "Second item"
        end
      end
      sidebar.to_s
    end

You can also use the Gestalt builder, which is a bit less verbose :


    def generate(current=nil)
      # Generate some HTML that will make the side bar

      sidebar = Ramaze::Gestalt.build do
        div(:class =>"sd") do
          h1 "This is a sidebar"
          ul do
            li "First item"
            li "Second item"
          end
        end
      end 
    end

## How can I disable all layout/view rendering in a specific action ?

You can use :

    body = "whatever"
    respond!(body, status, 'Content-Type' => 'whatever/foo')


## How do I use that flash thing to display flash messages ?

You can think of flash as a placeholder hash to send specific messsages in view
or layout.  For instance, let's say you need to display an alert box in the page
for the following situations :

* errors (oops, something went wrong)
* informations (user notificationa bout something normal)
* success (form has been handled properly)

You can decide on symbols (:error, :info, :success) and check in your layout if
flash has one of those keys set :

    <?r [:success, :error, :info].each do |type| ?>

      <?r if flash[type] ?>
        <div class="alert alert-block alert-#{type} fade in">
          <a class="close" data-dismiss="alert" href="#">×</a>
          <h4 class="alert-heading">#{type.capitalize}</h4>
          <p>#{flash[type].capitalize}</p>
        </div>
      <?r end ?>

    <?r end ?>

Then, if you set :

    flash[:error] = 'Invalid username'

you will display an alert box containing ‘Invalid username’ (this example uses
twitter bootstrap which brings CSS facilities to display those).

## What steps do I have to take to add pagination to my app ?

This is quite easy, it's just 4 lines of code to get started (assuming Sequel) :

* load the pagination helper in your controller

For instance, if you want to add pagination to your Albums controler, just add :

    class Albums < Ramaze::Controller
      ...
      helper :paginate
      ...

* make your controller method paginate the Sequel results (assuming Album is your model class) :

    class Albums < Ramaze::Controller
        #...
        def albumlist
          @albums = paginate(Album)
        end

* load the Sequel 'pagination' extension somewhere

model/init.rb is a good place if you have one :

    Sequel.extension(:pagination)

* display the navigation bar in your view :

    <table>
      <!-- this is the table where you display your data -->   
    </table>
    <center>#{@albums.navigation}</center>

# Database and models

## How can I cascade delete in my Sequel model ?

You can use sequel hooks for this. For instance, let's say you can to remove all
albums for an artist when you remove the artist, you can do so like this :

    class Artists < Sequel::Model
      one_to_many :albums
    
      def before_destroy
        Albums.filter(:domain_id => id).destroy
      end
    end

Thus, before removing an artist, all it's albums will be removed.

You can learn more about models hooks in the [sequel documentation][sqhooks]

# Authentication

## How can I add user authentication ?

The is a handy helper for this. Basically, all you have to do is to add an
authenticate class method to your user model.

The whole thing is explained in details in the {Ramaze::Helper::UserHelper} documentation.

As an example, here is a complete 'hello world' style application with 
authentication :

    require 'ramaze'
    
    class User
      def self.authenticate(credentials)
        credentials if credentials['name'] == 'manveru' && credentials['pass'] == 'foo'
      end
    end
    
    class Main < Ramaze::Controller
      map '/'
      helper :user
    
      def index
        redirect Users.r(:login) unless logged_in?
        'Hi #{user["name"]} #{Users.a :logout}'
      end
    end
    
    class Users < Ramaze::Controller
      map '/user'
      helper :user
    
      def login
        if request.post?
          user_login(request.subset(:name, :pass))
          redirect Main.r(:index)
        else
          <<-FORM
    <form method="post">
      <input type="text" name="name">
      <input type="password" name="pass">
      <input type="submit">
    </form>
          FORM
        end
      end
    
      def logout
        user_logout
        redirect r(:login)
      end
    end
    
    Ramaze.start
    

# Testing

## How set POST params in bacon tests ?

    post(“/login”, 
         ’username’ => ’manveru’,
         ’password’ => ’pass’).status.should == 200

## How can I follow a redirect when I receive a 302 in a test ?

Just use follow_redirect! :

    should 'add album for an artist' do
      post('/album/save',
           :artist  => 12,
           :title   => "Yorick's ballads",
           :style   => 'Deutch Folk').status.should == 302
      last_response['Content-Type'].should == 'text/html'
      follow_redirect!
      last_response['Content-Type'].should == 'text/html'
      last_response.should =~ /Album created successfully/
    end

## Can I run a test without running the whole test suite ?

Sure, assuming you require the right files in each spec file.
For instance, you can crete a ``helper.rb`` file in ``specs/`` like this :


    require 'ramaze'
    require 'ramaze/spec/bacon'

    require File.expand_path('../../app', __FILE__)

    puts "Running specs using database #{DB.opts[:database]}\n"

Then, in each spec file, add (ruby 1.9.3+) :

    require_relative './helper'

You can the execute your spec directly :

    ruby myspec.rb

## When I run my spec directly, I have complains about helpers

this is probably because your helpers are not loaded first in your
app.rb top file. Change it so the helpers are required first :

    require __DIR__('helper/init')
    require __DIR__('model/init')
    require __DIR__('controller/init')

## How can I make bacon more quiet ?

bacon accepts -Q to disable backtraces. 

If you use rake to start your tests, you can set backtrace on/off by setting an
environment variable. You can then check for this variable in your rake task :

    Bacon.const_set :Backtraces, false unless ENV['BACON_MUTE'].nil?

Starting you rake task like this (assuming the ‘spec’ task starts your tests) :

    BACON_MUTE=1 rake spec

will suppress bacon backtraces.

## What does 'behaves_like' means in bacon

behaves_like basically tells bacon to use a certain configuration for the
describe() block and let you use #get, #post, ... methods.

## What to return from a controller for an unacceptable operation ?

For instance, when a user creates a must-be-unique-record that already exists,
should I return a 406 , Or a 200 ?

When writing REST service, you probably want to use 4xx codes.  But If you write
a web application, just return a 200 and explain why it failed.

You can use flash[:error] for this.

[sqhooks]: http://sequel.rubyforge.org/rdoc/files/doc/model_hooks_rdoc.html

