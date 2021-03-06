#' Fetch zones for a 5-digit origin origin-destination pair
#'
#' For a given 5-digit origin and destination zip code pair, display the zone number and full response.
#'
#' @param origin_zip (character) A single origin zip as 5-digit character.
#' @param destination_zip (character) Required destination zip as 5-digit character.
#' @param show_details (boolean) Extract extra stuff from the response?
#' Specifically: \code{specific_to_priority_mail}, \code{local}, \code{same_ndc}, and \code{full_response}.
#' Get more info with \code{zone_detail_definitions}.
#' @param n_tries (numeric) Number times to try the API if at first we don't succeed.
#' @param verbose (boolean) Message what's going on?
#'
#' @details Displays the result of a query to the \href{https://postcalc.usps.com/DomesticZoneChart/}{"Get Zone for ZIP Code Pair"} tab of the USPS Zone Calc website.
#'
#' If you want all destinations for a given origin, use \code{fetch_zones_three_digit} with the first 3 digits of the origin; there you don't need to supply a destination.
#'
#' @seealso \link{fetch_zones_three_digit}
#'
#' @importFrom magrittr %>%
#'
#' @examples \dontrun{
#' fetch_zones_five_digit("90210", "20500")
#'
#' fetch_zones_five_digit("40360", "09756",
#'                        show_details = TRUE)
#'
#' # Supply multiple origins and destinations
#' purrr::map2_dfr(c("11238", "60647", "80205"),
#'                 c("98109", "02210", "94707"),
#'       fetch_zones_five_digit)
#' }
#'
#' @return A tibble with origin zip, destination zip and the USPS zone that origin-destination pair corresponds to. If \code{show_details} is TRUE, other columns are shown.
#' @export

fetch_zones_five_digit <- function(origin_zip, destination_zip,
                                   show_details = FALSE,
                                   n_tries = 3,
                                   verbose = FALSE) {
  origin_zip <-
    origin_zip %>%
    prep_zip(verbose = verbose)

  destination_zip <-
    destination_zip %>%
    prep_zip(verbose = verbose)

  resp <- get_zones_five_digit(
    origin_zip, destination_zip,
    n_tries = n_tries,
    verbose = verbose
  )

  if (resp$OriginError != "") stop("Invalid origin zip.")
  if (resp$DestinationError != "") stop("Invalid destination zip.")

  zone <-
    resp$ZoneInformation %>%
    stringr::str_extract("The Zone is [0-9]") %>%
    stringr::str_extract("[0-9]+")

  full_response <-
    resp$ZoneInformation

  out <-
    tibble::tibble(
      origin_zip = origin_zip,
      dest_zip = destination_zip,
      zone = zone,
      specific_to_priority_mail = NA, # Default to NA
      full_response = full_response
    ) %>%
    dplyr::mutate(
      specific_to_priority_mail = full_response %>%
        stringr::str_extract(
          "except for Priority Mail services where the Zone is [0-9]"
        ) %>%
        stringr::str_extract("[0-9]")
    )

  if (show_details == TRUE) {
    out <- out %>%
      dplyr::mutate(
        local =
          ! stringr::str_detect(
            full_response, "This is not a Local Zone"
        ),
        same_ndc =
          ! stringr::str_detect(
            full_response, "The destination ZIP Code is not \\
            within the same NDC as the origin ZIP Code"
          )
      ) %>%
      dplyr::select(
        origin_zip, dest_zip, zone,
        specific_to_priority_mail, local,
        same_ndc, full_response
      )
  } else {
    out <- out %>%
      dplyr::select(origin_zip, dest_zip, zone)
  }

  return(out)
}
