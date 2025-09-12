import OversizeMacro

@AutoRoutable
enum Screens {
    case meta
    case instagram
    case twitter
}

print(Screens.meta.id)
