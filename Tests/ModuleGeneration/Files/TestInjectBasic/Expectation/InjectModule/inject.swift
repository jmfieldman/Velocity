import Inject
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
    public func injectImplementations() {
        InjectionManager.register(InjectMapTypeOne.self) { InjectMapTypeOneImpl() }
        InjectionManager.register(InjectMapTypeTwo.self) { InjectMapTypeTwoImpl() }
        InjectionManager.register(InjectNoImplExample.self) { InjectNoImplExampleImpl() }
        InjectionManager.register(InjectsNameExampleOther.self) { InjectsNameExampleOtherImpl() }
        InjectionManager.register(InjectsUnderscoreExample.self) { InjectsUnderscoreExampleImpl() }
        InjectionManager.register(RecursiveInjectsExample.self) { RecursiveInjectsExampleImpl() }
    }
}