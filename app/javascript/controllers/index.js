// Import the Stimulus application
import { application } from "controllers/application"

// Import and register all controllers using importmap paths
import HelloController from "controllers/hello_controller"
application.register("hello", HelloController)

import BackgroundThreeController from "controllers/background_three_controller"
application.register("background-three", BackgroundThreeController)

import CategoryCardController from "controllers/category_card_controller"
application.register("category-card", CategoryCardController)

import HeroThreeController from "controllers/hero_three_controller"
application.register("hero-three", HeroThreeController)

import HoverEffectController from "controllers/hover_effect_controller"
application.register("hover-effect", HoverEffectController)

import LoadingAnimationController from "controllers/loading_animation_controller"
application.register("loading-animation", LoadingAnimationController)

import PageTransitionController from "controllers/page_transition_controller"
application.register("page-transition", PageTransitionController)

import ProductViewerController from "controllers/product_viewer_controller"
application.register("product-viewer", ProductViewerController)

import ScrollAnimationController from "controllers/scroll_animation_controller"
application.register("scroll-animation", ScrollAnimationController)
