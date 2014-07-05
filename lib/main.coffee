moduleName = 'a-package-loader'


measureTimes = {}
measureStart = (key) ->
  measureTimes[key] = Date.now()

measureEnd = (key) ->
  t2 = Date.now()
  t1 = measureTimes[key]
  t = t2-t1
  measureTimes[key + '.start'] = t1
  measureTimes[key + '.end'] = t2
  measureTimes[key] = t
  console.log key, t
  return t

uniq = (arr) ->
  arr.filter (value, index, self) ->
    self.indexOf(value) == index

measureStart 'packageLoader.requireMainModule'

path = require 'path'
async = null

deferredLoadingPackages = []
Package = null
defaultConfig = {
  'delayBetweenPackages': 50
  'deferredLoadingPackageNames': [
    'metrics'
    'tree-view'
  ]
  'ignorePackageNames': [
    'deprecation-cop'
    'status-bar'
    'tabs'
  ]
}
atom.config.setDefaults(moduleName, defaultConfig)

configGetWithDefault = (moduleName, key) ->
  uniq defaultConfig[key]?.concat atom.config.get(moduleName + '.' + key)

deferredLoadingPackageNames = configGetWithDefault moduleName, 'deferredLoadingPackageNames'
ignorePackageNames = configGetWithDefault moduleName, 'ignorePackageNames'

deferredLoadingPackageNames = deferredLoadingPackageNames.filter (value, index, self) ->
  value not in ignorePackageNames

console.log deferredLoadingPackageNames
console.log ignorePackageNames
atom.config.set(moduleName + '.ignorePackageNames', ignorePackageNames)

measureStart 'packageLoader.setDummyPackages'
packagePaths = atom.packages.getAvailablePackagePaths()
for packagePath in packagePaths
  packageName = path.basename(packagePath)
  # console.log packageName, packagePath, atom.packages.isPackageDisabled(packageName), atom.packages.isPackageLoaded(packageName)
  continue unless packageName in deferredLoadingPackageNames
  continue if atom.packages.isPackageLoaded(packageName)
  continue if atom.packages.isPackageDisabled(packageName)

  console.log 'packageLoader.defer: ', packageName
  Package ?= require(atom.packages.resourcePath + '\\src\\package')
  # packageName = 'tree-view'
  # packagePath = 'c:\\Atom\\Atom 0.106.0-88df4d2\\resources\\app\\node_modules\\tree-view'
  packageMetadata = {
    "name": packageName,
    "version": "unloaded",
    "engines": {
      "atom": ">0.50.0"
    },
    "dependencies": {
    }
  }
  pack = new Package(packagePath, packageMetadata)
  atom.packages.loadedPackages[pack.name] = pack
  deferredLoadingPackages.push pack
measureEnd 'packageLoader.setDummyPackages'

module.exports =

  times: {}

  activate: (state) ->
    measureStart 'packageLoader.activate'
    @times.waited = 0
    @bindTimeout()
    measureEnd 'packageLoader.activate'

  bindWindowLoad: ->
    measureStart 'atom.getCurrentWindow()'
    win = atom.getCurrentWindow()
    measureEnd 'atom.getCurrentWindow()'
    measureStart 'atom.isLoading()'
    isWinLoading = win.isLoading()
    measureEnd 'atom.isLoading()'

    if isWinLoading
      win.once 'window:loaded', =>
        cb = =>
          @onWindowLoaded()
        setTimeout cb, 0
    else
      cb = =>
        @onWindowLoaded()
      setTimeout cb, 0

  bindTimeout: ->
    cb = =>
      @onWindowLoaded()
    setTimeout(cb, 1500)

  addSlowLoadingPackages: (cb) ->
    measureStart 'packageLoader.addSlowLoadingPackages'
    for pack in atom.packages.getActivePackages()
      continue if pack.isTheme()
      continue if pack.name in ignorePackageNames
      continue if pack.name in deferredLoadingPackageNames
      continue if pack.name == moduleName

      if pack.loadTime + pack.activateTime > 30
        deferredLoadingPackageNames.push pack.name
    atom.config.set(moduleName + '.deferredLoadingPackageNames', uniq deferredLoadingPackageNames)
    measureEnd 'packageLoader.addSlowLoadingPackages'
    cb() if cb

  getStatusBarElement: ->
    atom.workspaceView.statusBar.find('.a-package-loader-status')

  setStatusBarMsg: (msg) ->
    el = @getStatusBarElement()
    unless el and el.length > 0
      console.log 'statusBar'
      atom.workspaceView.statusBar.appendLeft('<div class="a-package-loader-status inline-block"></div>')
    atom.workspaceView.statusBar.find('.a-package-loader-status').text(msg)

  removeStatusBarMsg: ->
    cb = ->
      @remove()
    atom.workspaceView.statusBar.find('.a-package-loader-status').fadeOut('fast', cb)

  onWindowLoaded: ->
    measureStart 'packageLoader.onWindowLoaded'
    @setStatusBarMsg('Loading Packages...')

    async ?= require 'async'
    console.log async
    async.series([
      (cb) => @loadDeferredLoadingPackages(cb),
      (cb) => @addSlowLoadingPackages(cb),
    ], (err) =>
      measureEnd 'packageLoader.onWindowLoaded'
      @deferredPackagesLoadTime = measureTimes['packageLoader.onWindowLoaded']
      @times.deferredPackagesLoadTime = measureTimes['packageLoader.onWindowLoaded']
      @times.totalLoadTime = atom.loadTime + @times.deferredPackagesLoadTime

      msg = 'Loaded in: ' + @times.totalLoadTime + 'ms (Background: ' + @times.deferredPackagesLoadTime + 'ms | Waited: ' + @times.waited + 'ms)'
      console.log msg
      @setStatusBarMsg(msg)
      cb = =>
        @removeStatusBarMsg()
      setTimeout cb, 5000
    )


  loadDeferredLoadingPackages: (cb) ->
    measureStart 'packageLoader.loadDeferredLoadingPackages'
    # for pack in deferredLoadingPackages
    #   @loadDeferredLoadingPackage(pack.name)

    async ?= require 'async'
    iterator = (pack, cb) =>
      delayBetweenPackages = atom.config.get(moduleName + '.delayBetweenPackages')
      cb2 = =>
        @times.waited += delayBetweenPackages
        setTimeout(cb, delayBetweenPackages) # Wait a bit so we don't freeze the editor.
      @loadDeferredLoadingPackage(pack.name, cb2)
    async.eachSeries(deferredLoadingPackages, iterator, =>
      measureEnd 'packageLoader.loadDeferredLoadingPackages'
      cb() if cb
    )

  loadDeferredLoadingPackage: (packageName, cb) ->
    console.log 'packageLoader.resolve: ', packageName
    t1 = Date.now()
    # atom.packages.deactivatePackage(packageName) if atom.packages.isPackageActive(packageName)
    # atom.packages.unloadPackage(packageName) if atom.packages.isPackageLoaded(packageName)
    delete atom.packages.activePackages[packageName] if atom.packages.isPackageActive(packageName)
    delete atom.packages.loadedPackages[packageName] if atom.packages.isPackageLoaded(packageName)
    t2 = Date.now()
    atom.packages.loadPackage(packageName)
    atom.packages.activatePackage(packageName)
    t3 = Date.now()
    p = atom.packages.getLoadedPackage(packageName)
    console.log '\tVersion: ', p.metadata.version
    console.log '\t\tUnload: ', t2-t1
    console.log '\t\tLoad: ', p.loadTime
    console.log '\t\tActivate: ', p.activateTime
    console.log '\t\tTook: ', t3-t1
    cb() if cb

measureEnd 'packageLoader.requireMainModule'
