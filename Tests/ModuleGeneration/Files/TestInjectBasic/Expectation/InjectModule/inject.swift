@_exported import Inject
import InjectNoImplExample
import InjectsMapExample
import InjectsMapExampleImpl
import InjectsNameExample
import InjectsNameExampleImpl
import InjectsUnderscoreExample
import InjectsUnderscoreExampleImpl
import RecursiveInjectsExample
import RecursiveInjectsExampleImpl

public extension InjectionManager {
    static func injectImplementations() {
        InjectionManager.unsafeRegister(InjectMapTypeOne.self) { InjectMapTypeOneImpl() }
        InjectionManager.unsafeRegister(InjectMapTypeTwo.self) { InjectMapTypeTwoImpl() }
        InjectionManager.unsafeRegister(InjectNoImplExample.self) { InjectNoImplExampleImpl() }
        InjectionManager.unsafeRegister(InjectsNameExampleOther.self) { InjectsNameExampleOtherImpl() }
        InjectionManager.unsafeRegister(InjectsUnderscoreExample.self) { InjectsUnderscoreExampleImpl() }
        InjectionManager.unsafeRegister(RecursiveInjectsExample.self) { RecursiveInjectsExampleImpl() }
    }
}

public extension BuilderManager {
    @MainActor static func builderImplementations() {

    }
}