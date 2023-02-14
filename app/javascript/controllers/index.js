// Load all the controllers within this directory and all subdirectories. 
// Controller files must be named *_controller.js.

import { Application } from "stimulus"
import { definitionsFromContext } from "stimulus/webpack-helpers"
// import jQuery from "jquery"

const application = Application.start()

// Configure Stimulus development experience
// application.debug = false
// window.Stimulus   = application
// window.jQuery = jQuery
// window.$ = jQuery


const context = require.context("controllers", true, /_controller\.js$/)
application.load(definitionsFromContext(context))
