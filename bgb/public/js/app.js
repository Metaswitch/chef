var app = app || {};

// Define Backbone app
$(function( $ ) {
  // Models
  app.Deployment = Backbone.Model.extend({ 
    urlRoot: '/deployments',
    
    initialize: function() {
      var self = this;
      var refresh = function() {
        self.fetch({
          success: function(model, response) {
            setTimeout(refresh, 2000);
          },
        });
      };
      refresh();
    }
  });

  app.DeploymentCollection = Backbone.Model.extend({ url: '/deployments' });

  // Views
  app.LaunchView = Backbone.View.extend({
    el: "#launch-container",

    events: {"click #launch-deployment": "launch"},

    initialize: function() {
      _.bindAll(this);
      var self = this;
      app.loadTemplate('create-deployment', function(data) {
        self.template = _.template(data);
        self.render();
      });
    },

    render: function(){
      this.$el.html(this.template());
    },

    launch: function () {
      var envName = this.$el.find("#name-field").val();
      var envSize = this.$el.find("#size-field").val();
      var deployment = new app.Deployment();
      deployment.save({"environment": envName, "size": envSize}, {
        success: function(model){
          app.router.navigate("deployments/" + model.id, {trigger: true});
        },
        error: function(){
          alert("Error starting deployment, please check input and try again");
        }
      });
    },
  });

  app.StatusView = Backbone.View.extend({
    el: "#status-container",

    initialize: function() {
      _.bindAll(this);
      var self = this;
      app.loadTemplate('deployment-status', function(data) {
        self.template = _.template(data);
      });
    },

    render: function(){
      this.$el.html(this.template(this.model.toJSON()));
    }
  });

  // Routes
  app.BGBRouter = Backbone.Router.extend({
    routes: {
      "": "main",
      "deployments/:environment": "deployment"
    },

    main: function() {
      app.showView(app.views.launchView);
    },

    deployment: function(environment) {
      var model = new app.Deployment({"id": environment});
      model.fetch({
        success: function(model, response) {
          app.views.statusView.model = model;
          app.showView(app.views.statusView);
          model.bind("change", app.views.statusView.render);
          model.trigger("change");
        },
        error: function(model, xhr) {
          if(xhr.status == "404"){
            // Could not find this model so re-direct to homepage
            alert("Couldn't find deployment " + model.id);
            app.router.navigate("", {trigger: true});
          }
        }
      });
    },
  });

  // Utility
  app.loadTemplate = function(name, success){
    $.get('js/templates/' + name + '.html', success);
  };

  app.showView = function(view) {
    if(app.views.current != undefined){
      app.views.current.$el.hide();
    }
    app.views.current = view;
    app.views.current.$el.fadeIn('slow');
  };
});

// Initialize app
$(function() {
  var deploymentCollection = new app.DeploymentCollection();
  app.views = {
    launchView: new app.LaunchView({"collection": deploymentCollection}),
    statusView: new app.StatusView(),
  };
  _.each(app.views, function(view){ view.$el.hide(); });

  app.router = new app.BGBRouter();
  Backbone.history.start();
});
