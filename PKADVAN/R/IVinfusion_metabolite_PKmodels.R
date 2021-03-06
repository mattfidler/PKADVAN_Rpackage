#' @title Process simulations using 1-compartment IV-infusion model with 1-compartment first-order formation metabolite model.
#' @description \code{OneCompIVinfusionOneCompMetab} function accepts NONMEM-style data frame for one subject and calculates drug amount in the respective compartments.
#' The data frame should have the following columns: \code{ID, TIME, AMT, RATE, CL, V, CLM, VM, FR}.
#'
#' where:
#' \tabular{ll}{
#' \code{ID}: \tab is the subject ID\cr
#' \code{TIME}:\tab is the sampling time points\cr
#' \code{AMT}:\tab is the dose\cr
#' \code{RATE}:\tab is the infusion rate\cr
#' \code{CL}:\tab is the central compartment clearance\cr
#' \code{V}:\tab is the central volume of distribution\cr
#' \code{CLM}:\tab is the central clearance of the metabolite\cr
#' \code{VM}:\tab is the        central volume of distribution of the metabolite\cr
#' \code{FR}:\tab is the        fraction of the parent drug converted into metabolite\cr
#' }
#'
#' @usage OneCompIVinfusionOneCompMetab(inputDataFrame)
#'
#' @param inputDataFrame which is the NONMEM-style data frame that contains columns for: \code{ID, TIME, AMT, RATE, CL, V1, Q2, V2, CLM, VM, FR}.\cr
#' @return The function calculates the parent and metabolite amounts in the respective compartments of the pharmacokinetic model.
#' This includes the amount in the parent central (\code{A1} & individual predicted parent concentrations, \code{IPREDP})
#' and metabolite central (\code{AM} & individual predicted metabolite concentrations, \code{IPREDM}) compartments.
#' The function returns the output added to the \code{inputDataFrame}
#'
#' @details
#' To simulate a population (i.e. the \code{inputDataFrame} has more than one subject \code{ID}),        the function
#' has to be applied for each subject \code{ID}. One way of doing that is through using the \code{ddply} functionality
#' in the \pkg{plyr} package in R. The \code{ddply} functionality allows applying the \pkg{PKADVAN} function to each subject
#' \code{ID} and combines the results into a data frame. Please load \pkg{plyr} package in \code{R} before
#' processsing simulations.
#'
#' \code{ddply(inputDataFrame, .(ID), OneCompIVinfusionOneCompMetab)}
#'
#' The \pkg{PKADVAN} function is capable of simulating arbitrary dosing regimens and can account for covariate structures; however,
#' covariate effects on respective parameters must be calculated prior processing simulations.
#' See examples below for more details.
#'
#' @seealso \code{\link{TwoCompIVinfusionOneCompMetab}}, \code{\link{ThreeCompIVinfusionOneCompMetab}}
#' @seealso \code{\link{OneCompIVbolusOneCompMetab}}, \code{\link{TwoCompIVbolusOneCompMetab}}, \code{\link{ThreeCompIVbolusOneCompMetab}}
#' @seealso \code{\link{OneCompFirstOrderAbsOneCompMetab}}, \code{\link{TwoCompFirstOrderAbsOneCompMetab}}, \code{\link{ThreeCompFirstOrderAbsOneCompMetab}}
#' @author Ahmad Abuhelwa\cr
#' Australian Center for Pharmacometrics\cr
#' School of Pharmacy and Medical Sciences\cr
#' University of South Australia\cr
#' \email{Ahmad.Abuhelwa@@myamil.unisa.edu.au}
#' @export
#------------------------------------------------------------------------------------
# IV infusion- 1 compartment parent with 1 compartment first-order metabolite formation
#------------------------------------------------------------------------------------
OneCompIVinfusionOneCompMetab <- function(inputDataFrame){
    #Accepts a NONMEM style data frame for 1 subject with columns for TIME, AMT, MDV, RATE, RATEALL, CL, V, CLM, VM, FR,
    #Returns a dataframe with populated columns for A1, AM, IPREDP, IPREDM

    #Setting variables to NULL first to avoid notes "no visible binding for global variable [variable name]" upon checking the package
    k10 <- kmf <- kme <- NULL
    RATEALL <- TIME <- CLpop1 <- CLpop2 <- NULL

    #Sampling Times
    sampletimes <- inputDataFrame$TIME

    #Process infusion doses: This function will add end infusion time points, if they are not already there.
    inputDataFrame <- ProcessInfusionDoses(inputDataFrame)

    #Calculate micro-rate constants
    FR = inputDataFrame$FR[1]
    inputDataFrame$CLpop1 <- inputDataFrame$CL*(1-FR)         # Clearance of the parent drug to outside the body
    inputDataFrame$CLpop2 <- inputDataFrame$CL*FR                         # Clearance of the parent drug into the metabolite compartment

    #Calculate micro-rate constants
    inputDataFrame$k10        <- inputDataFrame$CLpop1/inputDataFrame$V

    #Calculate micro-rate constants-Metabolite
    inputDataFrame$kmf <- inputDataFrame$CLpop2/inputDataFrame$V         #Rate constant for metabolite formation
    inputDataFrame$kme <- inputDataFrame$CLM/inputDataFrame$VM	 #Rate constant for metabolite elimination

    #set initial values in the compartments
    inputDataFrame$A1[inputDataFrame$TIME==0] <- 0        				         # Parent amount in the central compartment at time zero.
    inputDataFrame$AM[inputDataFrame$TIME==0] <- 0                                                                         # Amount in the metabolite compartment at time zero.

    OneCompIVinfusionOneCompMetabCpp( inputDataFrame )

    #Remove end infusion time points
    inputDataFrame <- subset(inputDataFrame, (TIME%in%sampletimes))

    #Calculate IPRED for the central compartment-Parent and Metabolite
    inputDataFrame$IPREDP <- inputDataFrame$A1/inputDataFrame$V         #Concentration of parent
    inputDataFrame$IPREDM <- inputDataFrame$AM/inputDataFrame$VM        #Concentration of metabolite

    #subset extra columns
    inputDataFrame <- subset(inputDataFrame, select=-c(k10,RATEALL,CLpop1,CLpop2,kmf,kme))

    #Return output
    inputDataFrame
}

#' @title Process simulations using 2-compartment IV-infusion model with 1-compartment first-order formation metabolite model.
#' @description \code{TwoCompIVinfusionOneCompMetab} function accepts NONMEM-style data frame for one subject and calculates drug amount in the respective compartments.
#' The data frame should have the following columns: \code{ID, TIME, AMT, RATE, CL, V1, Q2, V2, CLM, VM, FR}.
#'
#' where:
#' \tabular{ll}{
#' \code{ID}: \tab is the subject ID\cr
#' \code{TIME}:\tab is the sampling time points\cr
#' \code{AMT}:\tab is the dose\cr
#' \code{RATE}:\tab is the infusion rate\cr
#' \code{CL}:\tab is the central compartment clearance\cr
#' \code{V1}:\tab is the central volume of distribution\cr
#' \code{Q2}:\tab is the inter-compartmental clearance\cr
#' \code{V2}:\tab is the peripheral volume of distribution\cr
#' \code{CLM}:\tab is the central clearance of the metabolite\cr
#' \code{VM}:\tab is the        central volume of distribution of the metabolite\cr
#' \code{FR}:\tab is the        fraction of the parent drug converted into metabolite\cr
#' }
#'
#' @usage TwoCompIVinfusionOneCompMetab(inputDataFrame)
#'
#' @param inputDataFrame which is the NONMEM-style data frame that contains columns for: \code{ID, TIME, AMT, RATE, CL, V1, Q2, V2, CLM, VM, FR}.\cr
#' @return The function calculates the parent and metabolite amounts in the respective compartments of the pharmacokinetic model.
#' This includes the amount in the parent central (\code{A1} & individual predicted parent concentrations, \code{IPREDP})
#' parent two peripheral \code{(A2)}, and metabolite central (\code{AM} & individual predicted metabolite concentrations, \code{IPREDM}) compartments.
#' The function returns the output added to the \code{inputDataFrame}
#'
#' @details
#' To simulate a population (i.e. the \code{inputDataFrame} has more than one subject \code{ID}),        the function
#' has to be applied for each subject \code{ID}. One way of doing that is through using the \code{ddply} functionality
#' in the \pkg{plyr} package in R. The \code{ddply} functionality allows applying the \pkg{PKADVAN} function to each subject
#' \code{ID} and combines the results into a data frame. Please load \pkg{plyr} package in \code{R} before
#' processsing simulations.
#'
#' \code{ddply(inputDataFrame, .(ID), TwoCompIVinfusionOneCompMetab)}
#'
#' The \pkg{PKADVAN} function is capable of simulating arbitrary dosing regimens and can account for covariate structures; however,
#' covariate effects on respective parameters must be calculated prior processing simulations.
#' See examples below for more details.
#'
#' @seealso \code{\link{OneCompIVinfusionOneCompMetab}}, \code{\link{ThreeCompIVinfusionOneCompMetab}}
#' @seealso \code{\link{OneCompIVbolusOneCompMetab}}, \code{\link{TwoCompIVbolusOneCompMetab}}, \code{\link{ThreeCompIVbolusOneCompMetab}}
#' @seealso \code{\link{OneCompFirstOrderAbsOneCompMetab}}, \code{\link{TwoCompFirstOrderAbsOneCompMetab}}, \code{\link{ThreeCompFirstOrderAbsOneCompMetab}}
#' @author Ahmad Abuhelwa\cr
#' Australian Center for Pharmacometrics\cr
#' School of Pharmacy and Medical Sciences\cr
#' University of South Australia\cr
#' \email{Ahmad.Abuhelwa@@myamil.unisa.edu.au}
#' @export
#------------------------------------------------------------------------------------
# IV infusion- 2 compartment parent with 1 compartment first-order metabolite formation
#------------------------------------------------------------------------------------
TwoCompIVinfusionOneCompMetab <- function(inputDataFrame){
    #Accepts a NONMEM style data frame for 1 subject with columns for TIME, AMT,MDV, RATE, RATEALL, CL, V1, Q, V2, CLM, VM, FR
    #Returns a dataframe with populated columns for A1, A2, AM, IPREDP, IPREDM

    #Setting variables to NULL first to avoid notes "no visible binding for global variable [variable name]" upon checking the package
    k10 <- k12 <- k21 <- k20 <- kmf <- kme <- NULL
    RATEALL <- TIME <- CLpop1 <- CLpop2 <- NULL

    #Sampling Times
    sampletimes <- inputDataFrame$TIME

    #Process infusion doses
    inputDataFrame <- ProcessInfusionDoses(inputDataFrame)

    #Calculate micro-rate constants
    FR = inputDataFrame$FR[1]
    inputDataFrame$CLpop1 <- inputDataFrame$CL*(1-FR)         # Clearance of the parent drug to outside the body
    inputDataFrame$CLpop2 <- inputDataFrame$CL*FR                         # Clearance of the parent drug into the metabolite compartment

    #Calculate micro-rate constants
    inputDataFrame$k10 <- inputDataFrame$CLpop1/inputDataFrame$V1
    inputDataFrame$k12 <- inputDataFrame$Q/inputDataFrame$V1
    inputDataFrame$k21 <- inputDataFrame$Q/inputDataFrame$V2
    inputDataFrame$k20 <- 0

    #Calculate micro-rate constants-Metabolite
    inputDataFrame$kmf <- inputDataFrame$CLpop2/inputDataFrame$V1        #Rate constant for metabolite formation
    inputDataFrame$kme <- inputDataFrame$CLM/inputDataFrame$VM	 #Rate constant for metabolite elimination

    #set initial values in the compartments
    inputDataFrame$A1[inputDataFrame$TIME==0] <- 0        # Parent amount in the central compartment at time zero.
    inputDataFrame$A2[inputDataFrame$TIME==0] <- 0        # Parent amount in the peripheral compartment at time zero.
    inputDataFrame$AM[inputDataFrame$TIME==0] <- 0        # Metabolite amount in the metabolite compartment at time zero.

    TwoCompIVinfusionOneCompMetabCpp( inputDataFrame )

    #Remove end infusion time points
    inputDataFrame <- subset(inputDataFrame, (TIME%in%sampletimes))

    #Calculate IPRED for the central compartment-Parent and Metabolite
    inputDataFrame$IPREDP <- inputDataFrame$A1/inputDataFrame$V1        #Concentration of parent
    inputDataFrame$IPREDM <- inputDataFrame$AM/inputDataFrame$VM        #Concentration of metabolite

    #subset extra columns
    inputDataFrame <- subset(inputDataFrame, select=-c(k10,k12,k21,k20,RATEALL,CLpop1,CLpop2,kmf,kme))

    #Return output
    inputDataFrame
}

#' @title Process simulations using 3-compartment IV-infusion model with 1-compartment first-order formation metabolite model.
#' @description \code{ThreeCompIVinfusionOneCompMetab} function accepts NONMEM-style data frame for one subject and calculates drug amount in the respective compartments.
#' The data frame should have the following columns: \code{ID, TIME, AMT, RATE, CL, V1, Q2, V2, Q3, V3, CLM, VM, FR}.
#'
#' where:
#' \tabular{ll}{
#' \code{ID}: \tab is the subject ID\cr
#' \code{TIME}:\tab is the sampling time points\cr
#' \code{AMT}:\tab is the dose\cr
#' \code{RATE}:\tab is the infusion rate\cr
#' \code{CL}:\tab is the central compartment clearance\cr
#' \code{V1}:\tab is the central volume of distribution\cr
#' \code{Q2}:\tab is the inter-compartmental clearance (1)\cr
#' \code{V2}:\tab is the peripheral volume of distribution (1)\cr
#' \code{Q3}:\tab is the inter-compartmental clearance (2)\cr
#' \code{V3}:\tab is the peripheral volume of distribution (2)\cr
#' \code{CLM}:\tab is the central clearance of the metabolite\cr
#' \code{VM}:\tab is the        central volume of distribution of the metabolite\cr
#' \code{FR}:\tab is the        fraction of the parent drug converted into metabolite\cr
#' }
#'
#' @usage ThreeCompIVinfusionOneCompMetab(inputDataFrame)
#'
#' @param inputDataFrame which is the NONMEM-style data frame that contains columns for: \code{ID, TIME, AMT, RATE, CL, V1, Q2, V2, Q3, V3, CLM, VM, FR}.\cr
#' @return The function calculates the parent and metabolite amounts in the respective compartments of the pharmacokinetic model.
#' This includes the amount in the parent central (\code{A1} & individual predicted parent concentrations, \code{IPREDP})
#' parent two peripheral \code{(A2, A3)}, and metabolite central (\code{AM} & individual predicted metabolite concentrations, \code{IPREDM}) compartments.
#' The function returns the output added to the \code{inputDataFrame}
#'
#' @details
#' To simulate a population (i.e. the \code{inputDataFrame} has more than one subject \code{ID}),        the function
#' has to be applied for each subject \code{ID}. One way of doing that is through using the \code{ddply} functionality
#' in the \pkg{plyr} package in R. The \code{ddply} functionality allows applying the \pkg{PKADVAN} function to each subject
#' \code{ID} and combines the results into a data frame. Please load \pkg{plyr} package in \code{R} before
#' processsing simulations.
#'
#' \code{ddply(inputDataFrame, .(ID), ThreeCompIVinfusionOneCompMetab)}
#'
#' The \pkg{PKADVAN} function is capable of simulating arbitrary dosing regimens and can account for covariate structures; however,
#' covariate effects on respective parameters must be calculated prior processing simulations.
#' See examples below for more details.
#'
#' @seealso \code{\link{OneCompIVinfusionOneCompMetab}}, \code{\link{TwoCompIVinfusionOneCompMetab}}
#' @seealso \code{\link{OneCompIVbolusOneCompMetab}}, \code{\link{TwoCompIVbolusOneCompMetab}}, \code{\link{ThreeCompIVbolusOneCompMetab}}
#' @seealso \code{\link{OneCompFirstOrderAbsOneCompMetab}}, \code{\link{TwoCompFirstOrderAbsOneCompMetab}}, \code{\link{ThreeCompFirstOrderAbsOneCompMetab}}
#' @author Ahmad Abuhelwa\cr
#' Australian Center for Pharmacometrics\cr
#' School of Pharmacy and Medical Sciences\cr
#' University of South Australia\cr
#' \email{Ahmad.Abuhelwa@@myamil.unisa.edu.au}
#' @export

#------------------------------------------------------------------------------------
# IV infusion- 3 compartment parent with 1 compartment first-order metabolite formation
#------------------------------------------------------------------------------------
ThreeCompIVinfusionOneCompMetab <- function(inputDataFrame){
    #Accepts a NONMEM style data frame for 1 subject with columns for TIME, AMT, MDV, RATE, CL, V1, Q2, V2, Q3, V3, CLM, VM, FR,
    #Returns a dataframe with populated columns for A1, A2, A3, AM, IPREDP, IPREDM

    #Setting variables to NULL first to avoid notes "no visible binding for global variable [variable name]" upon checking the package
    k10 <- k12 <- k21 <- k20 <- k13 <- k31 <- k30 <- kmf <- kme <- NULL
    RATEALL <- TIME <- CLpop1 <- CLpop2 <- NULL

    #Sampling Times
    sampletimes <- inputDataFrame$TIME

    #Process infusion doses
    inputDataFrame <- ProcessInfusionDoses(inputDataFrame)

    #Calculate micro-rate constants-Parent
    FR = inputDataFrame$FR[1]
    inputDataFrame$CLpop1 <- inputDataFrame$CL*(1-FR)         # Clearance of the parent drug to outside the body
    inputDataFrame$CLpop2 <- inputDataFrame$CL*FR                         # Clearance of the parent drug into the metabolite compartment

    #Calculate rate constants
    inputDataFrame$k10 <- inputDataFrame$CLpop1/inputDataFrame$V1
    inputDataFrame$k12 <- inputDataFrame$Q2/inputDataFrame$V1
    inputDataFrame$k21 <- inputDataFrame$Q2/inputDataFrame$V2
    inputDataFrame$k20 <- 0
    inputDataFrame$k13 <- inputDataFrame$Q3/inputDataFrame$V1
    inputDataFrame$k31 <- inputDataFrame$Q3/inputDataFrame$V3
    inputDataFrame$k30 <- 0

    #Calculate micro-rate constants-Metabolite
    inputDataFrame$kmf <- inputDataFrame$CLpop2/inputDataFrame$V1        #Rate constant for metabolite formation
    inputDataFrame$kme <- inputDataFrame$CLM/inputDataFrame$VM	 #Rate constant for metabolite elimination

    #set initial values in the compartments
    inputDataFrame$A1[inputDataFrame$TIME==0] <- 0                                                                         # Amount in the central compartment at time zero.
    inputDataFrame$A2[inputDataFrame$TIME==0] <- 0                                                                         # Amount in the 1st peripheral compartment at time zero.
    inputDataFrame$A3[inputDataFrame$TIME==0] <- 0                                                                         # Amount in the 2nd peripheral compartment at time zero.
    inputDataFrame$AM[inputDataFrame$TIME==0] <- 0                                                                         # Amount in the metabolite compartment at time zero.

    ThreeCompIVinfusionOneCompMetabCpp( inputDataFrame )

    #Remove end infusion time points
    inputDataFrame <- subset(inputDataFrame, (TIME%in%sampletimes))

    #Calculate IPRED for the central compartment
    inputDataFrame$IPREDP <- inputDataFrame$A1/inputDataFrame$V1        #Concentration of parent
    inputDataFrame$IPREDM <- inputDataFrame$AM/inputDataFrame$VM        #Concentration of metabolite

    #subset extra columns
    inputDataFrame <- subset(inputDataFrame, select=-c(k10,k12,k21,k20,k13,k31,k30,RATEALL,CLpop1,CLpop2,kmf,kme))

    #Return output
    inputDataFrame
}
