# Controllers

## How can I handle HTTP verbs (GET, POST, ..) separately ?

You can inspect `request.env['REQUEST_METHOD']`. Here is a (contrived)
example that calls different methods depending on HTTP method used :

    class Robot < Ramaze::Controller
      def index(method, *args)
         real_method = request.env['REQUEST_METHOD'].downcase
         real_method << "_"  + method.downcase
         send(real_method, args) if self.class.method_defined?(real_method)
      end

      def get_me(*args)
        "Here is #{args.join ' '}"
      end

      def post_me(*args)
        "Sorry, can't post you #{args.join ' '}. Postoffice is closed."
      end
    end

This will be used like this :

    $ curl http://localhost:7000/robot/me/a/drink
    Here is a drink
    $ curl -d "" http://localhost:7000/robot/me/a/letter
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

This way, Ramaze will take care of loading your helper class
automatically. Then, in your layout, you just have to call your
`Sidebar#generate method` :

    <div class="sidebar-nav">
      #{generate}
    </div>

## How can I write HTML programatically

Just use {Ramaze::Gestalt}. It's a utility class that can help you
writing html programatically, so you don't have to "stuff" a String with
HTML, or use _here_ documents.

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

## How can I bypass all layout/view rendering in a specific action ?

You can use :

    body = "whatever"
    respond!(body, status, 'Content-Type' => 'whatever/foo')

## How can I retrieve which controller/method triggered my view/layout rendering ?

`action` contains this information. `action.node` holds the Controller
class name, and `action.method` the Controller's method.
However, `action.method` is not available in view and layout, so if you
really need them, you'll have to save the value in your controller.

For instance :

    class Controller < Ramaze::Controller
      before_all do
        @caller = { :controller => action.node, 
                    :method => action.method }
      end
    end

Then, if your controllers inherit Controller, you'll have access to the
@caller hash with :controller and :method entries in all your views and
layouts.

## How do I use that flash thing to display flash messages ?

You can think of flash as a placeholder hash to send specific messsages in view
or layout.  For instance, let's say you need to display an alert box in the page
for the following situations :

* errors (oops, something went wrong)
* informations (user notification about something normal)
* success (form has been handled properly)

You can decide on symbols (`:error`, `:info`, `:success`) and check in
your layout if flash has one of those keys set. The example below does
just this, and also use the key to set the CSS class for the alert box :

    <?r [:success, :error, :info].each do |type| ?>

      <?r if flash[type] ?>
        <div class="alert alert-block alert-#{type} fade in">
          <a class="close" data-dismiss="alert" href="#">×</a>
          <h4 class="alert-heading">#{type.capitalize}</h4>
          <p>#{flash[type]}</p>
        </div>
      <?r end ?>

    <?r end ?>

Then, if you set :

    flash[:error] = 'Invalid username'

in your controller you will display an alert box containing 'Invalid username'
(this example uses twitter bootstrap which brings CSS facilities to display
those).

## What steps do I have to take to add pagination to my app ?

This is quite easy, it's just 4 lines of code to get started (assuming Sequel) :

* load the pagination helper in your controller

For instance, if you want to add pagination to your Albums controler, just add :

    class Albums < Ramaze::Controller
      ...
      helper :paginate
      ...

* make your controller method paginate the Sequel results

Assuming Album is your model class :

    class Albums < Ramaze::Controller
      #...
      def albumlist
        @albums = paginate(Album)
      end

* load the Sequel 'pagination' extension somewhere

`model/init.rb` is a good place to load pagination if you have one :

    Sequel.extension(:pagination)

* display the navigation bar in your view

Now you just have to iterate over `@albums` to fetch the paginated
elements. You should also display the paginator somewhere in your page.

    <table>
    <!-- this is the table where you display your data -->
    <?r @albums.each do |a|
      <tr>
        <td>#{a.name}</td><td>...</td>
      </tr>
    <?r end ?>
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
        credentials if credentials['name'] == 'manveru' && credentials['pass'] == 'sensei'
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

    post("/login",
         'username' => 'manveru',
         'password' => 'sensei').status.should == 200

## How can I follow a redirect when I receive a 302 in a test ?

Just use `follow_redirect!` :

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

## When I use `follow_redirect!` I don't get the right page !

This is probably because your controller issues a `redirect_referer`
but the referer isn't set. so you end up on the '/' page.

You can force the referer in the POST request, passing a env hash as the
third argument :

    post('/album/save', { :artist => 12 }, { HTTP_REFERER => '/album/create' }

## Can I run a test without running the whole test suite ?

Sure, assuming you require the right files in each spec file.
For instance, you can crete a `helper.rb` file in `specs/` like this :


    require 'ramaze'
    require 'ramaze/spec/bacon'

    require File.expand_path('../../app', __FILE__)

    puts "Running specs using database #{DB.opts[:database]}\n"

Then, in each spec file, add (ruby 1.9.3+) :

    require_relative './helper'

You can the execute your spec directly :

    ruby myspec.rb

## When I run my spec directly, I have complaints about helpers

This is probably because your helpers are not loaded first in your
app.rb top file. Change it so the helpers are required first :

    require __DIR__('helper/init')
    require __DIR__('model/init')
    require __DIR__('controller/init')

## How can I make bacon more quiet ?

bacon accepts -Q to disable backtraces.

If you use rake to start your tests, you can set backtrace on/off by setting an
environment variable. You can then check for this variable in your rake task :

    Bacon.const_set :Backtraces, false unless ENV['BACON_MUTE'].nil?

Starting your rake task like this (assuming the _spec_ task starts your tests) :

    BACON_MUTE=1 rake spec

will suppress bacon backtraces.

## What does `behaves_like` means in bacon

`behaves_like` basically tells bacon to use a certain configuration for the
describe() block and let you use #get, #post, ... methods.

## What to return from a controller for an unacceptable operation ?

For instance, when a user creates a must-be-unique-record that already exists,
should I return a 406 , Or a 200 ?

When writing REST service, you probably want to use 4xx codes.  But If you write
a web application, just return a 200 and explain why it failed.

You can use `flash[:error]` for this.

## How can I pretend a user is authenticated in my tests

You can re-open the UserHelper class, and replace `#logged_in?` and
`#user`.
However, if you leave the class with the overrided methods, all specs
that will run after (even in other files) will get the new
behaviour.

Thus, you have to restore the class to it's original state when you
don't need to fake the authentication.

For instance, your spec file could look like this :

    # Let's override #user and #logged_in?
    module Ramaze
      module Helper
        module UserHelper
          def fake_logged_in?
            true
          end

          def fake_user
            User[:email=>'bonnie@example.org']
          end

          alias real_logged_in? logged_in?
          alias logged_in? fake_logged_in?

          alias real_user user
          alias user team_user
        end
      end
    end

    # many specs here that require to be authenticated

    # all specs are done here; we need to restore the
    # class to it's original state
    module Ramaze
      module Helper
        module UserHelper
          alias logged_in? real_logged_in?
          alias user real_user
        end
      end
    end

# Miscellany

## Rack stuff

### I want to handle a mime type specifically for a static asset

Rack::Mime::MIME_TYPES is a Hash holding mime type associations. You can
insert or change what you want in it.

For instance, if you write :

    Rack::Mime::MIME_TYPES['.gpx'] = 'application/octet-stream'

in app.rb (for instance), static files ending with GPX will be treated
as 'application/octet-stream' instead of the default 'text/plain'.

In this particular case, it will trigger a 'download' in the browser
instead of a in-browser display.

### Can I mount a rack application along with a Ramaze application ?

Yes, you can use `config.ru` for this.
For instance, let's say you want to serve static files with
Rack::Static, you can set-up a `config.ru` like this :

    require ::File.expand_path('../app', __FILE__)

    use Rack::Static, :urls => ["/doc"], :root => "doc"

    Ramaze.start(:root => Ramaze.options.roots, :started => true)
    run Ramaze

## Going live

### How can I use multiple workers in production ?

If you use thin, you can ask it to start multiple workers on different
ports. For instance, with this config file, you'll spin up three thin
instances on ports 5000, 5001, 5002 :

    pid: tmp/pids/thin.pid
    log: log/thin.log
    timeout: 30
    max_conns: 1024
    port: 5000
    max_persistent_conns: 512
    environment: live
    servers: 3
    address: 0.0.0.0
    daemonize: true

(note : you can do the same directly at the command line with ``
Then, start'em up with :

    RACK_ENV=live thin -C thinconfig.yml start

To use these instances, you need to set-up a reverse proxy.
The best tools for this are really haproxy and nginx

### I want to server my instances on port 80 with a reverse proxy

If apache already serves this port and you don't want to use Passenger,
you're not stuck.

Apache comes with two nifty modules : mod_proxy and mod_proxy_balancer. So you
can set-up apache as a front-end to your thin/unicorn workers. The configuration
is quite straightforward. Create a VirtualHost (if needed), and add the
following directives in your VirtualHost config filei :

    RewriteEngine On

    <Proxy balancer://thinservers>
        BalancerMember http://127.0.0.1:5000
        BalancerMember http://127.0.0.1:5001
        BalancerMember http://127.0.0.1:5002
    </Proxy>

    # Redirect all non-static requests to thin
    RewriteCond %{DOCUMENT_ROOT}/%{REQUEST_FILENAME} !-f
    RewriteRule ^/(.*)$ balancer://thinservers%{REQUEST_URI} [P,QSA,L]

    ProxyPass / balancer://thinservers/
    ProxyPassReverse / balancer://thinservers/
    ProxyPreserveHost on

    <Proxy *>
          Order deny,allow
          Allow from all
    </Proxy>

If you need a fallback server that responds _only_ when other servers
are dead, you can add a member in the `<Proxy>` directive with the
`status=+H` option :

    <Proxy balancer://thinservers>
        BalancerMember http://127.0.0.1:5000
        BalancerMember http://127.0.0.1:5001
        BalancerMember http://127.0.0.1:5002
        BalancerMember http://someserver.example.com:80 status=+H
    </Proxy>

### I use multiple workers in production an authentication is not working

Ramaze, by default, uses Ramaze::Cache::LRU, a in-memory cache, to store
th session. Since you have multple processes serving your app, the
session cache is not shared. You have to use a distributed cache like
Redis or MemCached, and tell Ramaze to use it :

    Ramaze::Cache.options.session = Ramaze::Cache::Redis

Don't forget to spin up Redis, add `gem 'redis'` in your Gemfile, and the problem
should be solved.

The nice side effect is that authentication will persist after
application restart, which is something that propably already annoyed
you in development mode right ?

### I have put code in `after` of `after_all`, but it's never called. Why ?

This is probably because you used `redirect_referrer` of `redirect` in your
method. When used, those method completely get out of execution flow and bypass
whatever code is next.

A workaround is to set `response.status` to a 30x (302, 303, ...) and add a
Location header.

    response.status = 302
    response.headers['Location'] = 'http://somewhere.el.se'

### How can I serve another directory containing static files ?

You can use the solution mentionned previously (see _Can I mount a rack
application along with a Ramaze application ?_) or go a simpler path by
asking Ramaze to server another directory. Just append the directory to
server to the `Ramaze.options.roots`. Static documents in the `public`
directory within will be served by Ramaze.

    # This will lookup for static files in
    # /home/me/myapp/otherdir/public too
    Ramaze.options.roots.push('/home/me/myapp/otherdir')

You can add this code to your `app.rb` for instance.


[sqhooks]: http://sequel.rubyforge.org/rdoc/files/doc/model_hooks_rdoc.html

