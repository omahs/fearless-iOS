typealias PhoneVerificationCodeModuleCreationResult = (view: PhoneVerificationCodeViewInput, input: PhoneVerificationCodeModuleInput)

protocol PhoneVerificationCodeViewInput: ControllerBackedProtocol {
    func set(phone: String)
    func didReceive(state: SCKYCPhoneCodeState)
}

protocol PhoneVerificationCodeViewOutput: AnyObject {
    func didLoad(view: PhoneVerificationCodeViewInput)
    func send(code: String)
    func didTapSendButton(with code: String)
    func didTapBackButton()
    func didTapCloseButton()
}

protocol PhoneVerificationCodeInteractorInput: AnyObject {
    func setup(with output: PhoneVerificationCodeInteractorOutput)
    func verify(code: String)
}

protocol PhoneVerificationCodeInteractorOutput: AnyObject {
    func didReceive(state: SCKYCPhoneCodeState)
    func didReceiveEmailVerificationStep(data: SCKYCUserDataModel)
    func didReceiveUserRegistrationStep(data: SCKYCUserDataModel)
    func didReceiveSignInSuccessfulStep(data: SCKYCUserDataModel)
}

protocol PhoneVerificationCodeRouterInput: PushDismissable {
    func presentIntroduce(from view: PhoneVerificationCodeViewInput?, data: SCKYCUserDataModel)
    func close(from view: PhoneVerificationCodeViewInput?)
}

protocol PhoneVerificationCodeModuleInput: AnyObject {}

protocol PhoneVerificationCodeModuleOutput: AnyObject {}
