import Foundation

enum SeedKnowledgeGraph {
    static func make() -> KnowledgeGraph {
        let sources = [
            SourceReference(id: "alphafold", title: "AlphaFold Protein Structure Database", publisher: "EMBL-EBI and DeepMind", url: URL(string: "https://alphafold.ebi.ac.uk"), license: "CC BY 4.0", reviewedDate: "2026-07-18"),
            SourceReference(id: "uniprot", title: "UniProt Knowledgebase", publisher: "UniProt Consortium", url: URL(string: "https://www.uniprot.org"), license: "CC BY 4.0", reviewedDate: "2026-07-18")
        ]

        let systems = [
            BiologicalSystem(id: "oxygen-transport", kind: .cardiovascular, name: "Oxygen Transport", shortDescription: "How blood carries oxygen to working tissues.", overview: "Oxygen transport links breathing, circulation, red blood cells, and energy use during daily activity.", whyItMatters: "Understanding this system helps explain why sustained exercise depends on coordinated lung, heart, blood, and muscle function.", icon: "heart.text.square", accentColors: ["#FF4D6D", "#7B2CBF"], pathways: ["heme-oxygen-binding"], proteinAccessions: ["P69905", "P68871", "P02144", "P02787"], moduleIDs: ["hemoglobin-function"]),
            BiologicalSystem(id: "muscle-contraction", kind: .musculoskeletal, name: "Muscle Contraction", shortDescription: "The protein machinery behind movement.", overview: "Muscle contraction emerges from coordinated actin, myosin, calcium handling, and energy transfer.", whyItMatters: "Workout and activity data can make the mechanics of movement a relevant topic to explore.", icon: "figure.strengthtraining.traditional", accentColors: ["#35D399", "#2F80ED"], pathways: ["sliding-filament"], proteinAccessions: ["P68133", "P12882", "P06732", "P00338", "O14983", "P14672"], moduleIDs: ["muscle-power"]),
            BiologicalSystem(id: "sleep-circadian", kind: .circadian, name: "Sleep and Circadian Biology", shortDescription: "Molecular timing systems that coordinate rest.", overview: "Circadian proteins regulate daily timing signals that interact with sleep, light exposure, and behavior.", whyItMatters: "Sleep records can make circadian regulation an interesting educational lens.", icon: "moon.stars", accentColors: ["#7C5CFF", "#00C2FF"], pathways: ["clock-feedback"], proteinAccessions: ["O15516", "Q9H2X6", "O15534", "O15055", "Q16526", "P48039", "P29274"], moduleIDs: ["circadian-loop"]),
            BiologicalSystem(id: "respiratory-biology", kind: .respiratory, name: "Respiratory Biology", shortDescription: "Gas exchange and breathing regulation.", overview: "Respiratory physiology connects airflow, oxygen saturation, carbon dioxide removal, and blood transport.", whyItMatters: "Respiratory measurements, when available, can point toward educational modules about breathing and gas exchange.", icon: "lungs", accentColors: ["#00C2FF", "#12B981"], pathways: ["gas-exchange"], proteinAccessions: ["P69905", "P68871", "P02144", "P02787", "P00918"], moduleIDs: ["gas-exchange-basics"]),
            BiologicalSystem(id: "cellular-energy", kind: .metabolic, name: "Cellular Energy", shortDescription: "How cells transform nutrients into usable energy.", overview: "Metabolism includes glucose transport, ATP production, lactate handling, and hormone signaling.", whyItMatters: "Activity and energy expenditure are useful entry points for learning how cells manage fuel.", icon: "bolt.heart", accentColors: ["#F59E0B", "#EF4444"], pathways: ["glucose-atp"], proteinAccessions: ["P06213", "P47871", "P48307", "P13807", "P52789", "P06744"], moduleIDs: ["cellular-atp"]),
            BiologicalSystem(id: "cardiac-signaling", kind: .cardiovascular, name: "Cardiac Signaling", shortDescription: "Molecular signals involved in heart response.", overview: "Heart rate response involves receptors, calcium handling, and contractile proteins.", whyItMatters: "Heart-rate summaries can make cardiac signaling a relevant educational topic without diagnosing heart function.", icon: "waveform.path.ecg", accentColors: ["#EF4444", "#2563EB"], pathways: ["adrenergic-calcium"], proteinAccessions: ["P08588", "P16615", "P45379", "Q8WZ42"], moduleIDs: ["cardiac-response"]),
            BiologicalSystem(id: "immune-defense", kind: .immune, name: "Immune System", shortDescription: "Recognition and defense proteins.", overview: "Immune biology uses antibodies, receptors, and signaling molecules to recognize and respond to threats.", whyItMatters: "This is a general learning area in the starter atlas.", icon: "shield.lefthalf.filled", accentColors: ["#10B981", "#6366F1"], pathways: ["immune-recognition"], proteinAccessions: ["P01857", "P01375", "P01584"], moduleIDs: ["immune-recognition"]),
            BiologicalSystem(id: "nervous-system", kind: .nervous, name: "Nervous System", shortDescription: "Signals, receptors, and neural communication.", overview: "Neural signaling depends on receptors, channels, and neurotransmitter pathways.", whyItMatters: "This topic connects general biology with sleep, focus, and movement education.", icon: "brain.head.profile", accentColors: ["#8B5CF6", "#06B6D4"], pathways: ["neural-signaling"], proteinAccessions: ["P29274", "P48039", "P35367"], moduleIDs: ["neural-signals"]),
            BiologicalSystem(id: "endocrine", kind: .endocrine, name: "Endocrine", shortDescription: "Hormones and receptors coordinating physiology.", overview: "Endocrine signaling helps coordinate metabolism, growth, stress, and energy storage.", whyItMatters: "This is a general learning area that relates to metabolism and exercise modules.", icon: "drop.triangle", accentColors: ["#EC4899", "#F59E0B"], pathways: ["hormone-receptors"], proteinAccessions: ["P06213", "P47871", "P48357"], moduleIDs: ["hormone-signaling"]),
            BiologicalSystem(id: "renal", kind: .renal, name: "Renal", shortDescription: "Filtration, fluid balance, and transport.", overview: "Kidney physiology uses membrane channels, transporters, and hormonal signals to manage fluids and electrolytes.", whyItMatters: "This is a general educational atlas topic in the MVP.", icon: "drop.degreesign", accentColors: ["#38BDF8", "#6366F1"], pathways: ["fluid-balance"], proteinAccessions: ["P41181", "P29972"], moduleIDs: ["fluid-balance"])
        ]

        let proteins = [
            protein("Hemoglobin subunit alpha", "HBA1", "P69905", "Oxygen binding and transport in red blood cells.", "Red blood cells", ["oxygen-transport", "respiratory-biology"], "oxygen binding", "hemoprotein"),
            protein("Hemoglobin subunit beta", "HBB", "P68871", "Oxygen carrier that forms adult hemoglobin with alpha subunits.", "Red blood cells", ["oxygen-transport", "respiratory-biology"], "oxygen binding", "hemoprotein"),
            protein("Myoglobin", "MB", "P02144", "Oxygen-binding protein that supports oxygen availability in muscle.", "Muscle cells", ["oxygen-transport", "muscle-contraction"], "oxygen storage", "hemoprotein"),
            protein("Transferrin", "TF", "P02787", "Iron transport protein important for hemoglobin production biology.", "Blood plasma", ["oxygen-transport", "respiratory-biology"], "iron binding", "transport protein"),
            protein("Cardiac troponin T", "TNNT2", "P45379", "Regulatory protein in cardiac muscle contraction.", "Cardiac sarcomere", ["cardiac-signaling"], "calcium-regulated contraction", "contractile protein"),
            protein("Cardiac troponin I", "TNNI3", "P19429", "Part of the troponin complex that regulates heart muscle contraction.", "Cardiac sarcomere", ["cardiac-signaling"], "calcium-regulated contraction", "contractile protein"),
            protein("Titin", "TTN", "Q8WZ42", "Large structural protein contributing to muscle elasticity.", "Sarcomere", ["muscle-contraction", "cardiac-signaling"], "structural support", "structural protein"),
            protein("SERCA2", "ATP2A2", "P16615", "Calcium pump involved in muscle relaxation and calcium handling.", "Sarcoplasmic reticulum", ["muscle-contraction", "cardiac-signaling"], "ion transport", "ATPase"),
            protein("Beta-1 adrenergic receptor", "ADRB1", "P08588", "Receptor involved in sympathetic signaling in heart tissue.", "Cell membrane", ["cardiac-signaling"], "receptor signaling", "GPCR"),
            protein("Actin alpha skeletal muscle", "ACTA1", "P68133", "Filament protein central to skeletal muscle contraction.", "Contractile fiber", ["muscle-contraction"], "motor scaffold", "cytoskeletal protein"),
            protein("Myosin heavy chain 7", "MYH7", "P12883", "Motor protein involved in cardiac and slow skeletal muscle contraction.", "Thick filament", ["muscle-contraction", "cardiac-signaling"], "motor activity", "motor protein"),
            protein("Creatine kinase M-type", "CKM", "P06732", "Supports rapid ATP buffering in muscle.", "Cytosol", ["muscle-contraction", "cellular-energy"], "phosphotransfer", "enzyme"),
            protein("Lactate dehydrogenase A", "LDHA", "P00338", "Enzyme involved in lactate and pyruvate interconversion.", "Cytosol", ["cellular-energy", "muscle-contraction"], "oxidoreductase", "enzyme"),
            protein("ATP synthase subunit beta", "ATP5F1B", "P06576", "Mitochondrial enzyme component that helps produce ATP.", "Mitochondrion", ["cellular-energy"], "ATP synthesis", "enzyme complex subunit"),
            protein("Glucose transporter type 4", "SLC2A4", "P14672", "Insulin-responsive glucose transporter in muscle and fat.", "Cell membrane", ["cellular-energy", "endocrine"], "glucose transport", "transporter"),
            protein("CLOCK", "CLOCK", "O15516", "Transcription factor involved in circadian rhythm regulation.", "Nucleus", ["sleep-circadian"], "transcription regulation", "transcription factor"),
            protein("BMAL1", "ARNTL", "O00327", "Core circadian transcription factor that partners with CLOCK.", "Nucleus", ["sleep-circadian"], "transcription regulation", "transcription factor"),
            protein("Period circadian protein homolog 1", "PER1", "O15534", "Circadian regulator participating in feedback timing loops.", "Nucleus and cytoplasm", ["sleep-circadian"], "circadian regulation", "regulatory protein"),
            protein("Period circadian protein homolog 2", "PER2", "O15055", "Circadian feedback protein important in daily timing regulation.", "Nucleus and cytoplasm", ["sleep-circadian"], "circadian regulation", "regulatory protein"),
            protein("Cryptochrome-1", "CRY1", "Q16526", "Circadian regulator that helps repress CLOCK-BMAL1 activity.", "Nucleus", ["sleep-circadian"], "circadian regulation", "regulatory protein"),
            protein("Melatonin receptor type 1A", "MTNR1A", "P48039", "Receptor involved in melatonin signaling.", "Cell membrane", ["sleep-circadian", "nervous-system"], "receptor signaling", "GPCR"),
            protein("Adenosine receptor A2A", "ADORA2A", "P29274", "Receptor related to adenosine signaling and sleep pressure biology.", "Cell membrane", ["sleep-circadian", "nervous-system"], "receptor signaling", "GPCR"),
            protein("Insulin receptor", "INSR", "P06213", "Receptor tyrosine kinase involved in insulin signaling.", "Cell membrane", ["cellular-energy", "endocrine"], "receptor signaling", "receptor tyrosine kinase"),
            protein("Glucagon receptor", "GCGR", "P47871", "Receptor involved in glucagon signaling and glucose regulation biology.", "Cell membrane", ["cellular-energy", "endocrine"], "receptor signaling", "GPCR"),
            protein("Leptin receptor", "LEPR", "P48357", "Receptor involved in energy balance signaling.", "Cell membrane", ["cellular-energy", "endocrine"], "cytokine receptor signaling", "receptor"),
            protein("Glycogen synthase", "GYS1", "P13807", "Enzyme involved in glycogen synthesis in muscle.", "Cytosol", ["cellular-energy"], "glycogen synthesis", "enzyme"),
            protein("Hexokinase-1", "HK1", "P19367", "Enzyme that phosphorylates glucose as an early glycolysis step.", "Cytosol and mitochondrion", ["cellular-energy"], "glucose phosphorylation", "enzyme"),
            protein("Carbonic anhydrase 1", "CA1", "P00915", "Enzyme that supports carbon dioxide transport chemistry in blood.", "Red blood cells", ["respiratory-biology"], "carbonate dehydration", "enzyme"),
            protein("Aquaporin-2", "AQP2", "P41181", "Water channel involved in kidney collecting duct water transport.", "Cell membrane", ["renal"], "water transport", "channel")
        ]

        let pathways = [
            Pathway(id: "heme-oxygen-binding", systemID: "oxygen-transport", name: "Heme oxygen binding", summary: "Hemoglobin and myoglobin use heme groups to reversibly bind oxygen.", proteinAccessions: ["P69905", "P68871", "P02144"]),
            Pathway(id: "sliding-filament", systemID: "muscle-contraction", name: "Sliding filament cycle", summary: "Actin and myosin convert ATP use into movement.", proteinAccessions: ["P68133", "P12883", "P16615"]),
            Pathway(id: "clock-feedback", systemID: "sleep-circadian", name: "CLOCK-BMAL1 feedback", summary: "Daily timing emerges from transcriptional feedback loops.", proteinAccessions: ["O15516", "O00327", "O15534", "O15055", "Q16526"]),
            Pathway(id: "glucose-atp", systemID: "cellular-energy", name: "Glucose to ATP", summary: "Cells transport and metabolize fuels to support ATP production.", proteinAccessions: ["P14672", "P19367", "P06576", "P00338"]),
            Pathway(id: "adrenergic-calcium", systemID: "cardiac-signaling", name: "Adrenergic calcium handling", summary: "Receptor signaling and calcium pumps coordinate heart response to demand.", proteinAccessions: ["P08588", "P16615", "P45379"])
        ]

        let modules = [
            EducationModule(id: "hemoglobin-function", systemID: "oxygen-transport", title: "How Hemoglobin Works", summary: "How hemoglobin binds oxygen, carries it through blood, and releases it in tissues.", steps: [
                EducationStep(id: "bind", title: "Oxygen binds to heme", body: "Oxygen can reversibly bind iron in heme groups within hemoglobin.", symbol: "circle.hexagongrid"),
                EducationStep(id: "transport", title: "Red blood cells carry it", body: "Red blood cells move hemoglobin through circulation so oxygen can reach distant tissues.", symbol: "arrow.triangle.branch"),
                EducationStep(id: "release", title: "Tissues favor release", body: "Local chemistry around active tissues can favor oxygen unloading from hemoglobin.", symbol: "drop"),
                EducationStep(id: "co2", title: "Carbon dioxide shifts binding", body: "Carbon dioxide and pH influence oxygen release; the app does not measure hemoglobin activity.", symbol: "aqi.medium")
            ], sourceIDs: ["uniprot"]),
            EducationModule(id: "muscle-power", systemID: "muscle-contraction", title: "How Muscle Contraction Works", summary: "How ATP, calcium, actin, and myosin support movement.", steps: [
                EducationStep(id: "calcium", title: "Calcium exposes binding sites", body: "Calcium signals shift regulatory proteins so myosin can interact with actin filaments.", symbol: "bolt.heart"),
                EducationStep(id: "bridge", title: "Myosin pulls actin", body: "Myosin heads bind actin and use ATP-linked shape changes to slide filaments past each other.", symbol: "arrow.left.and.right"),
                EducationStep(id: "recharge", title: "ATP resets the motor", body: "ATP binding and hydrolysis detach and re-cock myosin so repeated cycles can generate force.", symbol: "battery.100"),
                EducationStep(id: "relax", title: "Calcium returns to storage", body: "Calcium pumps help move calcium back into storage compartments so the fiber can relax.", symbol: "arrow.down.circle")
            ], sourceIDs: ["uniprot"]),
            EducationModule(id: "circadian-loop", systemID: "sleep-circadian", title: "How Circadian Timing Works", summary: "How CLOCK, BMAL1, PER, and CRY proteins participate in daily timing.", steps: [
                EducationStep(id: "activate", title: "CLOCK and BMAL1 start transcription", body: "CLOCK and BMAL1 can partner to activate genes involved in the circadian cycle.", symbol: "sunrise"),
                EducationStep(id: "accumulate", title: "PER and CRY accumulate", body: "PER and CRY proteins build up over time after their genes are expressed.", symbol: "hourglass"),
                EducationStep(id: "feedback", title: "Feedback slows the cycle", body: "Accumulated PER and CRY proteins help reduce CLOCK-BMAL1 activity, forming a feedback loop.", symbol: "arrow.triangle.2.circlepath"),
                EducationStep(id: "reset", title: "Signals tune the rhythm", body: "Light exposure, sleep timing, and behavior can influence the timing signals that feed into this system.", symbol: "moon.stars")
            ], sourceIDs: ["uniprot"]),
            EducationModule(id: "cellular-atp", systemID: "cellular-energy", title: "How Cellular Energy Works", summary: "How transporters, enzymes, and mitochondria turn fuel into ATP.", steps: [
                EducationStep(id: "uptake", title: "Fuel enters the cell", body: "Transporters such as GLUT4 help move glucose into cells when the right signals are present.", symbol: "rectangle.and.arrow.down"),
                EducationStep(id: "glycolysis", title: "Glucose is processed in steps", body: "Enzymes convert glucose through intermediate molecules while capturing usable energy.", symbol: "point.3.connected.trianglepath.dotted"),
                EducationStep(id: "mitochondria", title: "Mitochondria make most ATP", body: "Mitochondrial enzyme complexes use fuel-derived electrons to support ATP production.", symbol: "bolt.circle"),
                EducationStep(id: "buffer", title: "Cells buffer quick demand", body: "Systems such as creatine kinase help smooth fast-changing energy demand in tissues like muscle.", symbol: "waveform.path.ecg")
            ], sourceIDs: ["uniprot"]),
            EducationModule(id: "gas-exchange-basics", systemID: "respiratory-biology", title: "How Gas Exchange Works", summary: "How oxygen and carbon dioxide move between air, blood, and tissues.", steps: [
                EducationStep(id: "airflow", title: "Air reaches exchange surfaces", body: "Breathing brings fresh air to thin exchange surfaces in the lungs.", symbol: "wind"),
                EducationStep(id: "oxygen", title: "Oxygen moves into blood", body: "Oxygen moves from air spaces into nearby blood where it can bind transport proteins.", symbol: "arrow.down.to.line.compact"),
                EducationStep(id: "carbon-dioxide", title: "Carbon dioxide moves out", body: "Carbon dioxide produced by tissues is carried back toward the lungs and released into exhaled air.", symbol: "arrow.up.to.line.compact"),
                EducationStep(id: "transport", title: "Blood proteins support transport", body: "Hemoglobin and related proteins help coordinate oxygen delivery and carbon dioxide handling.", symbol: "heart.text.square")
            ], sourceIDs: ["uniprot"]),
            EducationModule(id: "cardiac-response", systemID: "cardiac-signaling", title: "How Heart Rate Response Works", summary: "How receptor signals, calcium handling, and ATP demand relate to changes in effort.", steps: [
                EducationStep(id: "signal", title: "Signals reach heart cells", body: "Adrenergic receptors help heart cells respond to nervous system signals during changing demand.", symbol: "antenna.radiowaves.left.and.right"),
                EducationStep(id: "calcium", title: "Calcium coordinates contraction", body: "Calcium-handling proteins help control the timing and strength of heart muscle contraction.", symbol: "waveform.path.ecg"),
                EducationStep(id: "energy", title: "Energy supply adapts", body: "Mitochondrial and metabolic proteins help support the ATP needs of repeated contraction.", symbol: "bolt.circle"),
                EducationStep(id: "recovery", title: "Recovery restores baseline", body: "Transporters and pumps help cells reset after each contraction and after periods of higher effort.", symbol: "arrow.counterclockwise")
            ], sourceIDs: ["uniprot"]),
            EducationModule(id: "immune-recognition", systemID: "immune-defense", title: "How Immune Recognition Works", summary: "How proteins participate in recognition, signaling, and coordinated defense.", steps: [
                EducationStep(id: "display", title: "Cells display molecular signals", body: "Surface proteins can present or expose molecular information that immune cells inspect.", symbol: "rectangle.grid.2x2"),
                EducationStep(id: "recognize", title: "Receptors detect patterns", body: "Immune receptors bind specific molecular features and help distinguish context.", symbol: "scope"),
                EducationStep(id: "communicate", title: "Signals coordinate response", body: "Cytokines and signaling proteins help immune cells communicate and organize activity.", symbol: "bubble.left.and.bubble.right"),
                EducationStep(id: "resolve", title: "Control mechanisms limit activity", body: "Regulatory proteins help keep immune signaling proportional and time-limited.", symbol: "slider.horizontal.3")
            ], sourceIDs: ["uniprot"]),
            EducationModule(id: "neural-signals", systemID: "nervous-system", title: "How Neural Signals Work", summary: "How receptors, ion channels, and transporters support signal transmission.", steps: [
                EducationStep(id: "resting", title: "Channels set electrical state", body: "Ion channels and pumps help establish the electrical gradients neurons use for signaling.", symbol: "bolt.horizontal.circle"),
                EducationStep(id: "trigger", title: "Signals change membrane voltage", body: "Opening specific channels changes ion flow and can trigger an electrical impulse.", symbol: "waveform"),
                EducationStep(id: "synapse", title: "Synapses pass information", body: "Neurotransmitter receptors and transporters help carry signals between cells.", symbol: "point.3.connected.trianglepath.dotted"),
                EducationStep(id: "reset", title: "Cells reset for the next signal", body: "Transport proteins help restore gradients and clear signaling molecules after transmission.", symbol: "arrow.counterclockwise.circle")
            ], sourceIDs: ["uniprot"]),
            EducationModule(id: "hormone-signaling", systemID: "endocrine", title: "How Hormone Signaling Works", summary: "How receptors relay endocrine messages across tissues.", steps: [
                EducationStep(id: "release", title: "Hormones enter circulation", body: "Endocrine tissues release hormones that can travel through blood to distant targets.", symbol: "drop.circle"),
                EducationStep(id: "bind", title: "Receptors recognize the signal", body: "Target cells respond when hormone molecules bind compatible receptor proteins.", symbol: "target"),
                EducationStep(id: "relay", title: "Cells relay the message", body: "Receptor activation can trigger intracellular signaling pathways or gene regulation.", symbol: "arrow.triangle.branch"),
                EducationStep(id: "feedback", title: "Feedback adjusts output", body: "Feedback loops help tune hormone production and response over time.", symbol: "arrow.triangle.2.circlepath")
            ], sourceIDs: ["uniprot"]),
            EducationModule(id: "fluid-balance", systemID: "renal", title: "How Fluid Balance Works", summary: "How channels and transporters support kidney water and salt handling.", steps: [
                EducationStep(id: "filter", title: "Blood is filtered", body: "Kidney structures filter fluid and small molecules while retaining many larger blood components.", symbol: "line.3.horizontal.decrease.circle"),
                EducationStep(id: "recover", title: "Useful molecules are reclaimed", body: "Transporters help recover water, salts, and nutrients that the body can reuse.", symbol: "arrow.uturn.backward.circle"),
                EducationStep(id: "tune", title: "Channels tune water movement", body: "Aquaporins and ion channels help adjust water and electrolyte movement across membranes.", symbol: "drop.degreesign"),
                EducationStep(id: "balance", title: "Output reflects many signals", body: "Fluid balance depends on hormones, circulation, intake, and kidney transporter activity.", symbol: "scale.3d")
            ], sourceIDs: ["uniprot"])
        ]

        return KnowledgeGraph(systems: systems, pathways: pathways, proteins: proteins, modules: modules, sources: sources)
    }

    private static func protein(_ name: String, _ gene: String, _ accession: String, _ function: String, _ location: String, _ systems: [String], _ molecularFunction: String, _ type: String) -> Protein {
        Protein(name: name, geneSymbol: gene, uniprotAccession: accession, organism: "Homo sapiens", functionSummary: function, cellularLocation: location, systems: systems, molecularFunction: molecularFunction, proteinType: type, alphaFoldAvailable: true, healthContextSummary: "HealthKit context can make this topic relevant to explore, but Molecyou does not measure this protein in your body.", sourceIDs: ["uniprot", "alphafold"])
    }
}
