////
///  ArtistInvitesProtocols.swift
//

protocol ArtistInvitesScreenDelegate: class {
    func scrollToTop()
}

protocol ArtistInviteAdminScreenProtocol: StreamableScreenProtocol {
    var selectedSubmissionsStatus: ArtistInviteSubmission.Status { get set }
}

protocol ArtistInviteAdminScreenDelegate: class {
    func tappedApprovedSubmissions()
    func tappedSelectedSubmissions()
    func tappedUnapprovedSubmissions()
}

protocol ArtistInviteConfigurableCell: class {
    var config: ArtistInviteBubbleCell.Config { get set }
}

protocol ArtistInviteResponder: class {
    func tappedArtistInviteSubmissionsButton()
    func tappedArtistInviteSubmitButton()
}
