Install = require '../models/install'
Forbidden = require '../models/forbidden'
User = require '../models/user'
gcm = require './gcm'

# Install model's CRUD controller.
class InstallController 

  # Lists all installs
  index: (req, res) ->
    Install.find {userId: req.params.user}, (err, installs) ->
      switch req.format
        when 'json' then res.json installs
        else res.render 'installs/index', {installs: installs, currentUser: req.params.user}

  new: (req, res) ->
    install = new Install
    install.userId = req.params.user
    res.render 'installs/new', {install: install, errs: null}

  edit: (req, res) ->
    Install.findOne {userId: req.params.user, appPkg: req.params.install}, (err, install) ->
      if err
        res.statusCode = 500
        install = err
      switch req.format
        when 'json' then res.json install
        else res.render 'installs/edit', {install: install, errs: null}

  # Creates new install with data from `req.body.install`
  create: (req, res) ->
    if typeof req.body.installs isnt 'undefined' and Object.prototype.toString.call(req.body.installs) is '[object Array]'
      addingUserToInstalls(req.params.user, req.body.installs)
      Install.collection.insert req.body.installs, (err, installs) ->
        if not err
          res.statusCode = 201
          res.send {installs: installs}
        else
          res.statusCode = 500
          res.send err
    else
      req.body.install.userId = req.params.user
      install = new Install req.body.install
      install.save (err, install) ->
        if not err
          res.send install
          res.statusCode = 201
        else
          res.send err
          res.statusCode = 500
        
  # Gets install by id
  show: (req, res) ->
    correctFormatToHtml req, res, 'install'
    Install.findOne {userId: req.params.user, appPkg: req.params.install}, (err, install) ->
      if err
        install = err
        res.statusCode = 500
      switch req.format
        when 'json' then res.json install
        else res.render 'installs/show', {install: install}

  # Updates install with data from `req.body.install`
  update: (req, res) ->
    req.params.install += "." + req.format if req.format isnt 'json' and typeof req.format isnt 'undefined'
    console.log 'Actions is ' + req.body.action
    install = null
    if req.body.action is 'add'
      Install.findOneAndUpdate {userId: req.params.user, appPkg: req.params.install}, {"$pushAll": {forbiddens:req.body.install.forbiddens}}, (err, install) ->
        responseResult(req, res, err, install)
    else if req.body.action is 'remove'
      startTimes = if typeof req.body.install.forbiddenStartTimes isnt 'undefined'
      then req.body.install.forbiddenStartTimes
      else req.body.install.forbiddens.map(mapForForbiddenStartTime)
      console.log "startTimes: "+startTimes
      Install.findOneAndUpdate {userId: req.params.user, appPkg: req.params.install}, {"$pull": {forbiddens:{startTime:{"$in":startTimes}}}}, (err, install) ->
        responseResult(req, res, err, install)
    else
      Install.findOneAndUpdate {userId: req.params.user, appPkg: req.params.install}, {"$set": req.body.install}, {upsert: true}, (err, install) ->
        responseResult(req, res, err, install)
    
  # Deletes install by id
  destroy: (req, res) ->
    correctFormatToHtml req, res, 'install'
    Install.findOneAndRemove {userId: req.params.user, appPkg: req.params.install} ,(err) ->
      if not err
        res.statusCode = 200
        res.send {}
      else
        res.statusCode = 500
        res.send err

module.exports = new InstallController

responseResult = (req, res, err, install) ->
  console.log 'format is ' + req.format
  if not err
    console.log 'Succeed updating install'
    console.log install
    res.statusCode = 200
    User.findOne {userId: req.params.user}, (err, user) ->
      if err?
        console.log err
      if user.gcmRegId?
        gcm.forbidden user.gcmRegId, install.appPkg
      else
        console.log (user.userId + " doesn't have gcmRegId")
  else
    console.log 'Failed updating install'
    res.statusCode = 500
    install = err
  switch req.format
    when 'json' then res.json install
    else
      res.type 'html'
      res.render 'installs/show', {install: install}

correctFormatToHtml = (req, res, param) ->
  if req.format isnt 'html' and req.format isnt 'json' and typeof req.format isnt 'undefined'
    req.params[param] += "." + req.format
    req.format = undefined
    res.type 'html'

addingUserToInstalls = (user, installs) ->
  for install in installs
    install.userId = user

mapForForbiddenStartTime = (forbidden) ->
  return forbidden.startTime
