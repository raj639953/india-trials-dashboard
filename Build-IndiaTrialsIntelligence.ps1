param(
    [string]$SourceJson = "C:\Users\raj63\Downloads\ctg-studies.json",
    [string]$OutputDir = "C:\Users\raj63\OneDrive\Documents\New project\india-trials-intelligence"
)

$ErrorActionPreference = "Stop"
Remove-Item Alias:H -ErrorAction SilentlyContinue

$dataDir = Join-Path $OutputDir "data"
$assetsDir = Join-Path $OutputDir "assets"
New-Item -ItemType Directory -Force -Path $dataDir, $assetsDir | Out-Null

function As-Array {
    param($Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [System.Array]) { return $Value }
    return @($Value)
}

function Clean-Text {
    param($Value)
    if ($null -eq $Value) { return "" }
    $text = [string]$Value
    return (($text -replace "\s+", " ").Trim())
}

function Join-Values {
    param($Values, [string]$Separator = " | ")
    $items = @(As-Array $Values | ForEach-Object { Clean-Text $_ } | Where-Object { $_ })
    return ($items -join $Separator)
}

function First-Text {
    param($Values)
    foreach ($value in (As-Array $Values)) {
        $text = Clean-Text $value
        if ($text) { return $text }
    }
    return ""
}

function H {
    param($Value)
    return [System.Net.WebUtility]::HtmlEncode((Clean-Text $Value))
}

function Format-DateValue {
    param($Struct)
    if ($null -eq $Struct) { return "" }
    if ($Struct.date) { return [string]$Struct.date }
    return Clean-Text $Struct
}

function Format-Phase {
    param($Phases)
    $items = @(As-Array $Phases | ForEach-Object {
        switch ([string]$_) {
            "EARLY_PHASE1" { "Early Phase 1"; break }
            "PHASE1" { "Phase 1"; break }
            "PHASE2" { "Phase 2"; break }
            "PHASE3" { "Phase 3"; break }
            "PHASE4" { "Phase 4"; break }
            "NA" { "Not Applicable"; break }
            default { if ($_ -and $_ -ne "N/A") { Clean-Text $_ } }
        }
    } | Where-Object { $_ })
    if ($items.Count -eq 0) { return "Not Provided" }
    if ($items.Count -eq 2 -and $items -contains "Phase 1" -and $items -contains "Phase 2") { return "Phase 1/2" }
    if ($items.Count -eq 2 -and $items -contains "Phase 2" -and $items -contains "Phase 3") { return "Phase 2/3" }
    return ($items -join " + ")
}

function Get-PhaseBucket {
    param([string]$Phase)
    switch -Regex ($Phase) {
        "Early Phase 1|Phase 1/2|Phase 1" { return "Early stage" }
        "Phase 2/3|Phase 2" { return "Mid stage" }
        "Phase 3|Phase 4" { return "Late / post-market" }
        "Not Applicable" { return "Not applicable" }
        default { return "Not provided" }
    }
}

function Rule-Match {
    param([string]$Text, [string[]]$Patterns)
    foreach ($pattern in $Patterns) {
        if ($Text -match $pattern) { return $pattern }
    }
    return $null
}

function Get-TherapeuticArea {
    param([string[]]$Signals)
    $text = (($Signals | Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() }) -join " ")

    $rules = @(
        @{ Area = "Oncology"; Patterns = @("cancer", "carcinoma", "neoplasm", "tumou?r", "malignan", "lymphoma", "leukemia", "leukaemia", "myeloma", "melanoma", "sarcoma", "glioma", "glioblastoma", "hepatocellular", "chemotherapy", "radiotherapy", "radiation therapy") },
        @{ Area = "Vaccines / Preventive Medicine"; Patterns = @("vaccine", "vaccination", "immunization", "immunisation", "prophylaxis", "preventive") },
        @{ Area = "Infectious Disease"; Patterns = @("infection", "infectious", "tuberculosis", "\btb\b", "\bhiv\b", "aids", "dengue", "malaria", "covid", "sars-cov-2", "influenza", "hepatitis", "sepsis", "bacterial", "viral", "antimicrobial", "pneumonia") },
        @{ Area = "Neurology / CNS"; Patterns = @("stroke", "parkinson", "alzheimer", "dementia", "epilep", "seizure", "migraine", "neuropath", "multiple sclerosis", "brain injury", "spinal cord", "neurolog", "cerebral", "cns", "myasthenia") },
        @{ Area = "Mental Health / Cognitive Health"; Patterns = @("depression", "anxiety", "schizophrenia", "bipolar", "psychosis", "psychiatr", "mental", "autism", "stress", "memory", "attention", "cognition", "cognitive", "sleep disorder", "insomnia") },
        @{ Area = "Cardiology / Vascular"; Patterns = @("heart", "cardiac", "cardio", "coronary", "myocardial", "hypertension", "arrhythmia", "atrial", "vascular", "thrombo", "embolism", "aortic", "peripheral artery", "heart failure") },
        @{ Area = "Endocrinology / Metabolic"; Patterns = @("diabetes", "diabetic", "obesity", "metabolic", "thyroid", "endocrine", "lipid", "hypercholester", "pcos", "polycystic ovary") },
        @{ Area = "Respiratory"; Patterns = @("asthma", "copd", "pulmonary", "respiratory", "bronch", "lung disease", "airway", "sleep apnea", "sleep apnoea") },
        @{ Area = "Gastroenterology / Hepatology"; Patterns = @("gastro", "liver", "hepatic", "cirrhosis", "bowel", "crohn", "ulcerative colitis", "colitis", "ibd", "pancrea", "esophag", "oesophag", "gastric", "intestinal", "constipation", "diarrhea", "diarrhoea") },
        @{ Area = "Nephrology / Urology"; Patterns = @("kidney", "renal", "dialysis", "urolog", "urinary", "bladder", "nephro", "chronic kidney") },
        @{ Area = "Hematology"; Patterns = @("anemia", "anaemia", "hemophilia", "haemophilia", "thalassemia", "sickle", "platelet", "thrombocyt", "coagulation", "hematolog", "haematolog", "\bblood\b") },
        @{ Area = "Immunology / Autoimmune"; Patterns = @("autoimmune", "lupus", "immune", "immunology", "immunologic", "rheumatoid", "inflammatory") },
        @{ Area = "Musculoskeletal / Rheumatology"; Patterns = @("arthritis", "osteoarthritis", "osteoporosis", "fracture", "knee", "hip", "shoulder", "musculoskeletal", "spondyl", "back pain", "joint", "bone") },
        @{ Area = "Dermatology"; Patterns = @("psoriasis", "dermat", "skin", "eczema", "acne", "hidradenitis", "urticaria", "alopecia") },
        @{ Area = "Ophthalmology"; Patterns = @("ophthalm", "\beye\b", "retina", "retinal", "macular", "glaucoma", "cataract", "vision", "ocular") },
        @{ Area = "Women's Health / Reproductive"; Patterns = @("pregnan", "maternal", "fertility", "reproductive", "menopause", "endometriosis", "uterine", "ovarian", "labor", "labour", "postpartum", "breastfeeding", "contraception") },
        @{ Area = "Pediatrics / Neonatology"; Patterns = @("pediatric", "paediatric", "neonat", "infant", "child", "children", "adolescent") },
        @{ Area = "Anesthesiology / Pain"; Patterns = @("anesthesia", "anaesthesia", "analges", "postoperative pain", "pain management", "chronic pain", "\bpain\b") },
        @{ Area = "Dental / Oral Health"; Patterns = @("dental", "periodontal", "orthodont", "oral health", "tooth", "teeth") },
        @{ Area = "Nutrition / Healthy Volunteer"; Patterns = @("healthy volunteer", "\bhealthy\b", "nutrition", "dietary", "supplement", "wellness", "exercise", "yoga") },
        @{ Area = "Devices / Diagnostics / Procedures"; Patterns = @("diagnostic", "imaging", "device", "surgery", "surgical", "procedure", "screening") }
    )

    foreach ($rule in $rules) {
        $match = Rule-Match -Text $text -Patterns $rule.Patterns
        if ($match) {
            return [pscustomobject]@{
                area = $rule.Area
                basis = $match
            }
        }
    }

    return [pscustomobject]@{
        area = "Other / Unclassified"
        basis = "No rule match"
    }
}

function Normalize-SponsorClass {
    param([string]$Value)
    switch ($Value) {
        "INDUSTRY" { "Industry" }
        "OTHER" { "Academic / Hospital / Other" }
        "OTHER_GOV" { "Government / Public sector" }
        "NIH" { "NIH" }
        "FED" { "Federal government" }
        "NETWORK" { "Network" }
        "INDIV" { "Individual" }
        default { if ($Value) { $Value } else { "Not Provided" } }
    }
}

function Add-Count {
    param([hashtable]$Map, [string]$Key, [int]$Amount = 1)
    $clean = if ($Key) { $Key } else { "Not Provided" }
    if (-not $Map.ContainsKey($clean)) { $Map[$clean] = 0 }
    $Map[$clean] += $Amount
}

function Count-By {
    param($Items, [string]$Property, [int]$Limit = 0)
    $groups = @($Items | Group-Object -Property $Property | ForEach-Object {
        [pscustomobject]@{ label = if ($_.Name) { $_.Name } else { "Not Provided" }; count = $_.Count }
    } | Sort-Object @{ Expression = "count"; Descending = $true }, @{ Expression = "label"; Descending = $false })
    if ($Limit -gt 0) { return @($groups | Select-Object -First $Limit) }
    return $groups
}

function To-ContactLabel {
    param($Contact)
    $bits = @()
    if ($Contact.name) { $bits += (Clean-Text $Contact.name) }
    if ($Contact.role) { $bits += ("Role: " + (Clean-Text $Contact.role)) }
    if ($Contact.phone) { $bits += ("Phone: " + (Clean-Text $Contact.phone)) }
    if ($Contact.email) { $bits += ("Email: " + (Clean-Text $Contact.email)) }
    return ($bits -join "; ")
}

Write-Host "Reading ClinicalTrials.gov JSON from $SourceJson"
$rawText = [System.IO.File]::ReadAllText($SourceJson, [System.Text.Encoding]::UTF8)
$studies = $rawText | ConvertFrom-Json
$sourceHash = (Get-FileHash -LiteralPath $SourceJson -Algorithm SHA256).Hash
$buildTimestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")

$trials = New-Object System.Collections.Generic.List[object]
$siteRows = New-Object System.Collections.Generic.List[object]
$contactRows = New-Object System.Collections.Generic.List[object]

foreach ($study in $studies) {
    $p = $study.protocolSection
    $id = $p.identificationModule
    $status = $p.statusModule
    $sponsor = $p.sponsorCollaboratorsModule
    $design = $p.designModule
    $conditions = @(As-Array $p.conditionsModule.conditions | ForEach-Object { Clean-Text $_ } | Where-Object { $_ })
    $keywords = @(As-Array $p.conditionsModule.keywords | ForEach-Object { Clean-Text $_ } | Where-Object { $_ })
    $meshes = @(As-Array $study.derivedSection.conditionBrowseModule.meshes | ForEach-Object { Clean-Text $_.term } | Where-Object { $_ })
    $ancestors = @(As-Array $study.derivedSection.conditionBrowseModule.ancestors | ForEach-Object { Clean-Text $_.term } | Where-Object { $_ })
    $interventions = @(As-Array $p.armsInterventionsModule.interventions)
    $interventionNames = @($interventions | ForEach-Object { Clean-Text $_.name } | Where-Object { $_ })
    $interventionTypes = @($interventions | ForEach-Object { Clean-Text $_.type } | Where-Object { $_ } | Sort-Object -Unique)
    $signals = @()
    $signals += $conditions
    $signals += $keywords
    $signals += $meshes
    $signals += $ancestors
    $signals += $interventionNames
    $signals += Clean-Text $id.briefTitle
    $signals += Clean-Text $id.officialTitle
    $therapeutic = Get-TherapeuticArea -Signals $signals
    $phase = Format-Phase $design.phases

    $allLocations = @(As-Array $p.contactsLocationsModule.locations)
    $indiaLocations = @($allLocations | Where-Object { (Clean-Text $_.country) -eq "India" })
    $indiaStates = @($indiaLocations | ForEach-Object { Clean-Text $_.state } | Where-Object { $_ } | Sort-Object -Unique)
    $indiaCities = @($indiaLocations | ForEach-Object { Clean-Text $_.city } | Where-Object { $_ } | Sort-Object -Unique)
    $indiaFacilities = @($indiaLocations | ForEach-Object { Clean-Text $_.facility } | Where-Object { $_ } | Sort-Object -Unique)
    $centralContacts = @(As-Array $p.contactsLocationsModule.centralContacts)
    $officials = @(As-Array $p.contactsLocationsModule.overallOfficials)
    $collaborators = @(As-Array $sponsor.collaborators)
    $secondaryIds = @(As-Array $id.secondaryIdInfos | ForEach-Object { Clean-Text $_.id } | Where-Object { $_ })
    $primaryOutcomes = @(As-Array $p.outcomesModule.primaryOutcomes | ForEach-Object {
        [pscustomobject]@{
            measure = Clean-Text $_.measure
            timeFrame = Clean-Text $_.timeFrame
            description = Clean-Text $_.description
        }
    })
    $secondaryOutcomes = @(As-Array $p.outcomesModule.secondaryOutcomes | ForEach-Object {
        [pscustomobject]@{
            measure = Clean-Text $_.measure
            timeFrame = Clean-Text $_.timeFrame
        }
    })

    $siteContactCount = 0
    $siteEmailCount = 0
    $sitePhoneCount = 0
    $siteIndex = 0
    foreach ($loc in $indiaLocations) {
        $siteIndex += 1
        $locationContacts = @(As-Array $loc.contacts)
        $siteContactCount += $locationContacts.Count
        $siteEmailCount += @($locationContacts | Where-Object { Clean-Text $_.email }).Count
        $sitePhoneCount += @($locationContacts | Where-Object { Clean-Text $_.phone }).Count
        $siteId = "$($id.nctId)-SITE-$siteIndex"
        $siteRows.Add([pscustomobject]@{
            siteId = $siteId
            nctId = Clean-Text $id.nctId
            title = Clean-Text $id.briefTitle
            therapeuticArea = $therapeutic.area
            phase = $phase
            overallStatus = Clean-Text $status.overallStatus
            sponsor = Clean-Text $sponsor.leadSponsor.name
            sponsorClass = Normalize-SponsorClass (Clean-Text $sponsor.leadSponsor.class)
            facility = Clean-Text $loc.facility
            siteStatus = Clean-Text $loc.status
            city = Clean-Text $loc.city
            state = Clean-Text $loc.state
            zip = Clean-Text $loc.zip
            country = Clean-Text $loc.country
            latitude = if ($loc.geoPoint) { $loc.geoPoint.lat } else { $null }
            longitude = if ($loc.geoPoint) { $loc.geoPoint.lon } else { $null }
            contactCount = $locationContacts.Count
            emailContactCount = @($locationContacts | Where-Object { Clean-Text $_.email }).Count
            phoneContactCount = @($locationContacts | Where-Object { Clean-Text $_.phone }).Count
        }) | Out-Null

        foreach ($contact in $locationContacts) {
            $contactRows.Add([pscustomobject]@{
                contactId = "$siteId-CONTACT-$($contactRows.Count + 1)"
                nctId = Clean-Text $id.nctId
                title = Clean-Text $id.briefTitle
                source = "India site"
                facility = Clean-Text $loc.facility
                city = Clean-Text $loc.city
                state = Clean-Text $loc.state
                name = Clean-Text $contact.name
                role = Clean-Text $contact.role
                phone = Clean-Text $contact.phone
                email = Clean-Text $contact.email
            }) | Out-Null
        }
    }

    foreach ($contact in $centralContacts) {
        $contactRows.Add([pscustomobject]@{
            contactId = "$($id.nctId)-CENTRAL-$($contactRows.Count + 1)"
            nctId = Clean-Text $id.nctId
            title = Clean-Text $id.briefTitle
            source = "Central contact"
            facility = ""
            city = ""
            state = ""
            name = Clean-Text $contact.name
            role = Clean-Text $contact.role
            phone = Clean-Text $contact.phone
            email = Clean-Text $contact.email
        }) | Out-Null
    }

    $hasContactEmail = (($siteEmailCount + @($centralContacts | Where-Object { Clean-Text $_.email }).Count) -gt 0)
    $hasContactPhone = (($sitePhoneCount + @($centralContacts | Where-Object { Clean-Text $_.phone }).Count) -gt 0)
    $hasAnyContact = (($siteContactCount + $centralContacts.Count) -gt 0)

    $trialLocations = @($indiaLocations | ForEach-Object {
        [pscustomobject]@{
            facility = Clean-Text $_.facility
            status = Clean-Text $_.status
            city = Clean-Text $_.city
            state = Clean-Text $_.state
            zip = Clean-Text $_.zip
            country = Clean-Text $_.country
            latitude = if ($_.geoPoint) { $_.geoPoint.lat } else { $null }
            longitude = if ($_.geoPoint) { $_.geoPoint.lon } else { $null }
            contacts = @(As-Array $_.contacts | ForEach-Object {
                [pscustomobject]@{
                    name = Clean-Text $_.name
                    role = Clean-Text $_.role
                    phone = Clean-Text $_.phone
                    email = Clean-Text $_.email
                }
            })
        }
    })

    $trial = [pscustomobject]@{
        nctId = Clean-Text $id.nctId
        trialUrl = "https://clinicaltrials.gov/study/$($id.nctId)"
        orgStudyId = Clean-Text $id.orgStudyIdInfo.id
        secondaryIds = $secondaryIds
        organizationName = Clean-Text $id.organization.fullName
        organizationClass = Clean-Text $id.organization.class
        briefTitle = Clean-Text $id.briefTitle
        officialTitle = Clean-Text $id.officialTitle
        acronym = Clean-Text $id.acronym
        overallStatus = Clean-Text $status.overallStatus
        statusVerifiedDate = Clean-Text $status.statusVerifiedDate
        startDate = Format-DateValue $status.startDateStruct
        primaryCompletionDate = Format-DateValue $status.primaryCompletionDateStruct
        completionDate = Format-DateValue $status.completionDateStruct
        lastUpdatePostDate = Format-DateValue $status.lastUpdatePostDateStruct
        studyFirstPostDate = Format-DateValue $status.studyFirstPostDateStruct
        leadSponsor = Clean-Text $sponsor.leadSponsor.name
        leadSponsorClass = Normalize-SponsorClass (Clean-Text $sponsor.leadSponsor.class)
        leadSponsorClassRaw = Clean-Text $sponsor.leadSponsor.class
        collaborators = @($collaborators | ForEach-Object {
            [pscustomobject]@{ name = Clean-Text $_.name; class = Clean-Text $_.class }
        })
        responsiblePartyType = Clean-Text $sponsor.responsibleParty.type
        responsibleInvestigator = Clean-Text $sponsor.responsibleParty.investigatorFullName
        responsibleInvestigatorTitle = Clean-Text $sponsor.responsibleParty.investigatorTitle
        responsibleInvestigatorAffiliation = Clean-Text $sponsor.responsibleParty.investigatorAffiliation
        studyType = Clean-Text $design.studyType
        phase = $phase
        phaseBucket = Get-PhaseBucket $phase
        rawPhases = @(As-Array $design.phases | ForEach-Object { Clean-Text $_ } | Where-Object { $_ })
        allocation = Clean-Text $design.designInfo.allocation
        interventionModel = Clean-Text $design.designInfo.interventionModel
        primaryPurpose = Clean-Text $design.designInfo.primaryPurpose
        masking = Clean-Text $design.designInfo.maskingInfo.masking
        enrollmentCount = $design.enrollmentInfo.count
        enrollmentType = Clean-Text $design.enrollmentInfo.type
        conditions = $conditions
        keywords = $keywords
        meshTerms = $meshes
        therapeuticArea = $therapeutic.area
        therapeuticAreaBasis = $therapeutic.basis
        interventionTypes = $interventionTypes
        interventionNames = $interventionNames
        armCount = @(As-Array $p.armsInterventionsModule.armGroups).Count
        interventionCount = $interventions.Count
        primaryOutcomes = $primaryOutcomes
        secondaryOutcomeCount = $secondaryOutcomes.Count
        secondaryOutcomes = $secondaryOutcomes
        sex = Clean-Text $p.eligibilityModule.sex
        minimumAge = Clean-Text $p.eligibilityModule.minimumAge
        maximumAge = Clean-Text $p.eligibilityModule.maximumAge
        healthyVolunteers = $p.eligibilityModule.healthyVolunteers
        standardAges = @(As-Array $p.eligibilityModule.stdAges | ForEach-Object { Clean-Text $_ } | Where-Object { $_ })
        briefSummary = Clean-Text $p.descriptionModule.briefSummary
        detailedDescription = Clean-Text $p.descriptionModule.detailedDescription
        eligibilityCriteria = Clean-Text $p.eligibilityModule.eligibilityCriteria
        indiaSiteCount = $indiaLocations.Count
        globalSiteCount = $allLocations.Count
        indiaStates = $indiaStates
        indiaCities = $indiaCities
        indiaFacilities = $indiaFacilities
        indiaLocations = $trialLocations
        centralContacts = @($centralContacts | ForEach-Object {
            [pscustomobject]@{ name = Clean-Text $_.name; role = Clean-Text $_.role; phone = Clean-Text $_.phone; email = Clean-Text $_.email }
        })
        overallOfficials = @($officials | ForEach-Object {
            [pscustomobject]@{ name = Clean-Text $_.name; role = Clean-Text $_.role; affiliation = Clean-Text $_.affiliation }
        })
        hasAnyContact = $hasAnyContact
        hasContactEmail = $hasContactEmail
        hasContactPhone = $hasContactPhone
        siteContactCount = $siteContactCount
        centralContactCount = $centralContacts.Count
        hasResults = [bool]$study.hasResults
        sourceVersion = Clean-Text $study.derivedSection.miscInfoModule.versionHolder
    }
    $trials.Add($trial) | Out-Null
}

$summary = [ordered]@{}
$summary.sourceFile = $SourceJson
$summary.sourceSha256 = $sourceHash
$summary.generatedAt = $buildTimestamp
$summary.totalStudiesInSource = $studies.Count
$summary.totalIndiaTrials = $trials.Count
$summary.recruitingTrials = @($trials | Where-Object { $_.overallStatus -eq "RECRUITING" }).Count
$summary.notYetRecruitingTrials = @($trials | Where-Object { $_.overallStatus -eq "NOT_YET_RECRUITING" }).Count
$summary.indiaSiteCount = $siteRows.Count
$summary.stateRegionCount = @($siteRows | Where-Object { $_.state } | Select-Object -ExpandProperty state -Unique).Count
$summary.cityCount = @($siteRows | Where-Object { $_.city } | Select-Object -ExpandProperty city -Unique).Count
$summary.facilityCount = @($siteRows | Where-Object { $_.facility } | Select-Object -ExpandProperty facility -Unique).Count
$summary.contactRecordCount = $contactRows.Count
$summary.emailContactCount = @($contactRows | Where-Object { $_.email }).Count
$summary.phoneContactCount = @($contactRows | Where-Object { $_.phone }).Count
$summary.trialsWithAnyContact = @($trials | Where-Object { $_.hasAnyContact }).Count
$summary.trialsWithEmail = @($trials | Where-Object { $_.hasContactEmail }).Count
$summary.trialsWithPhone = @($trials | Where-Object { $_.hasContactPhone }).Count
$summary.trialsWithIndiaSites = @($trials | Where-Object { $_.indiaSiteCount -gt 0 }).Count

$stateRows = @($siteRows | Group-Object -Property state | ForEach-Object {
    $rows = @($_.Group)
    [pscustomobject]@{
        label = if ($_.Name) { $_.Name } else { "Not Provided" }
        siteCount = $rows.Count
        trialCount = @($rows | Select-Object -ExpandProperty nctId -Unique).Count
        contactCount = ($rows | Measure-Object -Property contactCount -Sum).Sum
    }
} | Sort-Object @{ Expression = "trialCount"; Descending = $true }, @{ Expression = "siteCount"; Descending = $true }, @{ Expression = "label"; Descending = $false })

$cityRows = @($siteRows | Group-Object -Property city,state | ForEach-Object {
    $rows = @($_.Group)
    $first = $rows[0]
    [pscustomobject]@{
        label = if ($first.city -and $first.state) { "$($first.city), $($first.state)" } elseif ($first.city) { $first.city } else { "Not Provided" }
        city = $first.city
        state = $first.state
        siteCount = $rows.Count
        trialCount = @($rows | Select-Object -ExpandProperty nctId -Unique).Count
        contactCount = ($rows | Measure-Object -Property contactCount -Sum).Sum
    }
} | Sort-Object @{ Expression = "trialCount"; Descending = $true }, @{ Expression = "siteCount"; Descending = $true }, @{ Expression = "label"; Descending = $false })

$counts = [ordered]@{
    therapeuticArea = @(Count-By -Items $trials -Property therapeuticArea)
    phase = @(Count-By -Items $trials -Property phase)
    phaseBucket = @(Count-By -Items $trials -Property phaseBucket)
    status = @(Count-By -Items $trials -Property overallStatus)
    sponsorClass = @(Count-By -Items $trials -Property leadSponsorClass)
    primaryPurpose = @(Count-By -Items $trials -Property primaryPurpose)
    studyType = @(Count-By -Items $trials -Property studyType)
    topSponsors = @(Count-By -Items $trials -Property leadSponsor -Limit 25)
    stateRegion = $stateRows
    city = $cityRows
    topCities = @($cityRows | Select-Object -First 25)
    topStates = @($stateRows | Select-Object -First 25)
}

$interventionTypeMap = @{}
foreach ($trial in $trials) {
    foreach ($type in $trial.interventionTypes) { Add-Count -Map $interventionTypeMap -Key $type }
    if ($trial.interventionTypes.Count -eq 0) { Add-Count -Map $interventionTypeMap -Key "Not Provided" }
}
$counts.interventionType = @($interventionTypeMap.GetEnumerator() | ForEach-Object {
    [pscustomobject]@{ label = $_.Key; count = $_.Value }
} | Sort-Object @{ Expression = "count"; Descending = $true }, @{ Expression = "label"; Descending = $false })

$conditionMap = @{}
foreach ($trial in $trials) {
    foreach ($condition in $trial.conditions) { Add-Count -Map $conditionMap -Key $condition }
}
$counts.topConditions = @($conditionMap.GetEnumerator() | ForEach-Object {
    [pscustomobject]@{ label = $_.Key; count = $_.Value }
} | Sort-Object @{ Expression = "count"; Descending = $true }, @{ Expression = "label"; Descending = $false } | Select-Object -First 30)

function Top-Share {
    param($Rows, [string]$CountProperty = "count", [int]$Top = 5)
    $total = ($Rows | Measure-Object -Property $CountProperty -Sum).Sum
    if (-not $total) { return 0 }
    $topSum = ($Rows | Select-Object -First $Top | Measure-Object -Property $CountProperty -Sum).Sum
    return [math]::Round(($topSum / $total) * 100, 1)
}

$topArea = $counts.therapeuticArea | Select-Object -First 1
$topPhase = $counts.phase | Select-Object -First 1
$topState = $counts.stateRegion | Select-Object -First 1
$topSponsorClass = $counts.sponsorClass | Select-Object -First 1
$summary.insights = @(
    "Largest therapeutic area: $($topArea.label) ($($topArea.count) trials, $([math]::Round(($topArea.count / [double]$trials.Count) * 100, 1))%).",
    "Top five therapeutic areas account for $(Top-Share -Rows $counts.therapeuticArea -CountProperty count -Top 5)% of classified trials.",
    "Largest phase group: $($topPhase.label) ($($topPhase.count) trials).",
    "Most represented India state/region field: $($topState.label) ($($topState.trialCount) unique trials across $($topState.siteCount) site records).",
    "Largest sponsor class: $($topSponsorClass.label) ($($topSponsorClass.count) trials).",
    "$($summary.trialsWithEmail) of $($summary.totalIndiaTrials) trials have at least one email contact in central or India-site contact records."
)

$analysis = [ordered]@{
    summary = $summary
    counts = $counts
    trials = $trials
    sites = $siteRows
    contacts = $contactRows
    methodology = [ordered]@{
        scope = "ClinicalTrials.gov studies in the supplied JSON with India site locations. Location analysis uses India locations only; global site counts are retained separately."
        activeStatusesObserved = @($counts.status | ForEach-Object { $_.label })
        noHallucinationControls = @(
            "Sponsor, location, contact, phase, status, outcome, eligibility, and intervention fields are extracted from the supplied JSON.",
            "Therapeutic areas are derived from conditions, keywords, MeSH terms, ancestor terms, titles, and intervention names using visible rule-based keyword matching.",
            "Missing values are rendered as Not Provided; sponsor addresses are not invented when not present in the JSON.",
            "ClinicalTrials.gov state fields are displayed as reported because some records use district or regional labels."
        )
    }
}

Write-Host "Writing processed datasets"
$json = $analysis | ConvertTo-Json -Depth 100
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $dataDir "analysis-data.json"), $json, $utf8NoBom)
[System.IO.File]::WriteAllText((Join-Path $dataDir "analysis-data.js"), "window.INDIA_TRIALS_DATA = $json;", $utf8NoBom)
$trials | Select-Object nctId, overallStatus, therapeuticArea, phase, phaseBucket, leadSponsor, leadSponsorClass, studyType, primaryPurpose, enrollmentCount, indiaSiteCount, globalSiteCount, @{n="indiaStates";e={$_.indiaStates -join " | "}}, @{n="indiaCities";e={$_.indiaCities -join " | "}}, hasAnyContact, hasContactEmail, hasContactPhone, trialUrl, briefTitle | Export-Csv -NoTypeInformation -Encoding UTF8 -Path (Join-Path $dataDir "trials.csv")
$siteRows | Export-Csv -NoTypeInformation -Encoding UTF8 -Path (Join-Path $dataDir "india-sites.csv")
$contactRows | Export-Csv -NoTypeInformation -Encoding UTF8 -Path (Join-Path $dataDir "contacts.csv")
Copy-Item -LiteralPath $SourceJson -Destination (Join-Path $dataDir "source-ctg-studies.json") -Force

function Legend-Html {
    param($Rows, [int]$Limit = 12)
    $colors = @("#1f77b4", "#2ca02c", "#ff7f0e", "#9467bd", "#d62728", "#17becf", "#8c564b", "#bcbd22", "#e377c2", "#7f7f7f", "#1b9e77", "#7570b3")
    $i = 0
    $sb = New-Object System.Text.StringBuilder
    foreach ($row in ($Rows | Select-Object -First $Limit)) {
        $color = $colors[$i % $colors.Count]
        [void]$sb.Append("<div class='legend-row'><span style='background:$color'></span><strong>$(H $row.label)</strong><em>$($row.count)</em></div>")
        $i += 1
    }
    return $sb.ToString()
}

function Conic-Style {
    param($Rows, [string]$CountProperty = "count", [int]$Limit = 10)
    $colors = @("#1f77b4", "#2ca02c", "#ff7f0e", "#9467bd", "#d62728", "#17becf", "#8c564b", "#bcbd22", "#e377c2", "#7f7f7f")
    $top = @($Rows | Select-Object -First $Limit)
    $total = ($top | Measure-Object -Property $CountProperty -Sum).Sum
    if (-not $total) { return "background:#ddd" }
    $start = 0.0
    $segments = @()
    for ($i = 0; $i -lt $top.Count; $i++) {
        $val = [double]$top[$i].$CountProperty
        $end = $start + (($val / $total) * 360.0)
        $segments += "$($colors[$i % $colors.Count]) $([math]::Round($start, 2))deg $([math]::Round($end, 2))deg"
        $start = $end
    }
    return "background:conic-gradient($($segments -join ', '))"
}

function Bar-Rows-Html {
    param($Rows, [string]$CountProperty = "count", [int]$Limit = 15)
    $top = @($Rows | Select-Object -First $Limit)
    $max = ($top | Measure-Object -Property $CountProperty -Maximum).Maximum
    if (-not $max) { $max = 1 }
    $sb = New-Object System.Text.StringBuilder
    foreach ($row in $top) {
        $width = [math]::Max(4, [math]::Round((([double]$row.$CountProperty / [double]$max) * 100), 1))
        [void]$sb.Append("<div class='bar-row'><div><strong>$(H $row.label)</strong><span>$($row.$CountProperty)</span></div><i style='width:$width%'></i></div>")
    }
    return $sb.ToString()
}

Write-Host "Writing PDF-ready report"
$report = New-Object System.Text.StringBuilder
[void]$report.AppendLine("<!doctype html><html lang='en'><head><meta charset='utf-8'><title>India Active Clinical Trials Intelligence Report</title><link rel='stylesheet' href='assets/report.css'></head><body>")
[void]$report.AppendLine("<section class='cover'><p class='eyebrow'>ClinicalTrials.gov India Active Trials</p><h1>India Active Clinical Trials Intelligence Report</h1><p class='subtitle'>Therapeutic area, phase, sponsor, state/city/site, and contact analysis from the supplied JSON source.</p><dl><dt>Generated</dt><dd>$(H $summary.generatedAt)</dd><dt>Studies</dt><dd>$($summary.totalIndiaTrials)</dd><dt>India site records</dt><dd>$($summary.indiaSiteCount)</dd><dt>Source SHA-256</dt><dd>$(H $sourceHash)</dd></dl></section>")
[void]$report.AppendLine("<section><h2>Executive Summary</h2><div class='metric-grid'><div><b>$($summary.totalIndiaTrials)</b><span>active India trials</span></div><div><b>$($summary.indiaSiteCount)</b><span>India site records</span></div><div><b>$($summary.stateRegionCount)</b><span>state/region values as reported</span></div><div><b>$($summary.cityCount)</b><span>cities</span></div><div><b>$($summary.contactRecordCount)</b><span>contact records</span></div><div><b>$($summary.trialsWithEmail)</b><span>trials with email contact</span></div></div><h3>Analyst Observations</h3><ul>")
foreach ($insight in $summary.insights) { [void]$report.AppendLine("<li>$(H $insight)</li>") }
[void]$report.AppendLine("</ul></section>")
[void]$report.AppendLine("<section><h2>Portfolio Charts</h2><div class='chart-grid'><div class='chart-panel'><h3>Therapeutic Areas</h3><div class='pie' style='$(Conic-Style $counts.therapeuticArea)'></div><div class='legend'>$(Legend-Html $counts.therapeuticArea)</div></div><div class='chart-panel'><h3>Trial Phases</h3><div class='pie' style='$(Conic-Style $counts.phase)'></div><div class='legend'>$(Legend-Html $counts.phase)</div></div><div class='chart-panel'><h3>Sponsor Class</h3><div class='pie' style='$(Conic-Style $counts.sponsorClass)'></div><div class='legend'>$(Legend-Html $counts.sponsorClass)</div></div><div class='chart-panel'><h3>Recruitment Status</h3><div class='pie' style='$(Conic-Style $counts.status)'></div><div class='legend'>$(Legend-Html $counts.status)</div></div></div></section>")
[void]$report.AppendLine("<section><h2>India Location and Sponsor Concentration</h2><div class='two-col'><div><h3>Top State/Region Fields by Unique Trials</h3>$(Bar-Rows-Html -Rows $counts.stateRegion -CountProperty trialCount -Limit 20)</div><div><h3>Top Cities by Unique Trials</h3>$(Bar-Rows-Html -Rows $counts.city -CountProperty trialCount -Limit 20)</div></div><div class='two-col'><div><h3>Top Lead Sponsors</h3>$(Bar-Rows-Html -Rows $counts.topSponsors -CountProperty count -Limit 20)</div><div><h3>Intervention Types</h3>$(Bar-Rows-Html -Rows $counts.interventionType -CountProperty count -Limit 20)</div></div></section>")
[void]$report.AppendLine("<section><h2>Methodology and Controls</h2><p>$(H $analysis.methodology.scope)</p><ul>")
foreach ($control in $analysis.methodology.noHallucinationControls) { [void]$report.AppendLine("<li>$(H $control)</li>") }
[void]$report.AppendLine("</ul></section>")
[void]$report.AppendLine("<section><h2>Full Classified Trial Directory</h2>")
foreach ($trial in ($trials | Sort-Object therapeuticArea, phase, briefTitle)) {
    [void]$report.AppendLine("<article class='trial'><h3>$(H $trial.briefTitle)</h3><p class='nct'><a href='$(H $trial.trialUrl)'>$(H $trial.nctId)</a> · $(H $trial.overallStatus) · $(H $trial.therapeuticArea) · $(H $trial.phase)</p><table><tbody>")
    [void]$report.AppendLine("<tr><th>Official title</th><td>$(H $trial.officialTitle)</td></tr>")
    [void]$report.AppendLine("<tr><th>Conditions</th><td>$(H ($trial.conditions -join '; '))</td></tr>")
    [void]$report.AppendLine("<tr><th>Lead sponsor</th><td>$(H $trial.leadSponsor) ($(H $trial.leadSponsorClass))</td></tr>")
    [void]$report.AppendLine("<tr><th>Collaborators</th><td>$(H (($trial.collaborators | ForEach-Object { $_.name }) -join '; '))</td></tr>")
    [void]$report.AppendLine("<tr><th>Design</th><td>Study type: $(H $trial.studyType); purpose: $(H $trial.primaryPurpose); allocation: $(H $trial.allocation); model: $(H $trial.interventionModel); masking: $(H $trial.masking)</td></tr>")
    [void]$report.AppendLine("<tr><th>Enrollment</th><td>$(H $trial.enrollmentCount) $(H $trial.enrollmentType)</td></tr>")
    [void]$report.AppendLine("<tr><th>Dates</th><td>Start: $(H $trial.startDate); primary completion: $(H $trial.primaryCompletionDate); completion: $(H $trial.completionDate); last update: $(H $trial.lastUpdatePostDate)</td></tr>")
    [void]$report.AppendLine("<tr><th>Interventions</th><td>$(H (($trial.interventionTypes -join ', ') + ' - ' + ($trial.interventionNames -join '; ')))</td></tr>")
    [void]$report.AppendLine("<tr><th>Eligibility</th><td>Sex: $(H $trial.sex); age: $(H $trial.minimumAge) to $(H $trial.maximumAge); healthy volunteers: $(H $trial.healthyVolunteers)</td></tr>")
    [void]$report.AppendLine("<tr><th>Brief summary</th><td>$(H $trial.briefSummary)</td></tr>")
    $central = @($trial.centralContacts | ForEach-Object { To-ContactLabel $_ } | Where-Object { $_ })
    [void]$report.AppendLine("<tr><th>Central contacts</th><td>$(H ($central -join ' | '))</td></tr>")
    [void]$report.AppendLine("</tbody></table><h4>India Sites and Contacts</h4>")
    if ($trial.indiaLocations.Count -eq 0) {
        [void]$report.AppendLine("<p>Not Provided</p>")
    } else {
        [void]$report.AppendLine("<table><thead><tr><th>Facility</th><th>City</th><th>State/Region</th><th>Status</th><th>Contacts</th></tr></thead><tbody>")
        foreach ($loc in $trial.indiaLocations) {
            $contacts = @($loc.contacts | ForEach-Object { To-ContactLabel $_ } | Where-Object { $_ })
            [void]$report.AppendLine("<tr><td>$(H $loc.facility)</td><td>$(H $loc.city)</td><td>$(H $loc.state)</td><td>$(H $loc.status)</td><td>$(H ($contacts -join ' | '))</td></tr>")
        }
        [void]$report.AppendLine("</tbody></table>")
    }
    [void]$report.AppendLine("</article>")
}
[void]$report.AppendLine("</section></body></html>")
[System.IO.File]::WriteAllText((Join-Path $OutputDir "India_Clinical_Trials_Report.html"), $report.ToString(), $utf8NoBom)

Write-Host "Done. Trials: $($summary.totalIndiaTrials); India sites: $($summary.indiaSiteCount); contacts: $($summary.contactRecordCount)"
